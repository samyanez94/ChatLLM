//
//  ChatLLMStreamingTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 10/11/26.
//

@testable import ChatLLM
import Foundation
import Testing

struct ChatLLMStreamingTests {
	@Test("SSE accepts byte-fragmented Unicode, CRLF, comments and multiline JSON")
	func fragments() throws {
		var decoder = ChatLLMStreamDecoder(provider: "openai", model: "test")
		let wire = ": heartbeat\r\n\r\nevent: delta\r\ndata: {\r\ndata: \"text\":\"Hi 🌎\"}\r\n\r\nevent: completed\r\ndata: {\"provider\":\"openai\",\"model\":\"test\"}\r\n\r"
		var updates = [String]()
		for byte in wire.utf8 {
			if try decoder.append(byte) {
				updates.append(decoder.text)
			}
		}
		try decoder.finish()
		#expect(updates == ["Hi 🌎"])
		#expect(decoder.isComplete)
	}

	@Test(
		"Missing completion, malformed frames and mismatched models fail",
		arguments: [
			"event: delta\ndata: {\"text\":\"partial\"}\n\n",
			"event: delta\ndata: not-json\n\n",
			"event: completed\ndata: {\"provider\":\"openai\",\"model\":\"test\"}\n\n",
			"event: delta\ndata: {\"text\":\"partial\"}\n\nevent: completed\ndata: {\"provider\":\"other\",\"model\":\"test\"}\n\n",
			"event: unknown\ndata: {}\n\n"
		]
	)
	func invalidStreams(wire: String) {
		#expect(throws: ChatLLMClientError.self) {
			var decoder = ChatLLMStreamDecoder(provider: "openai", model: "test")
			for byte in wire.utf8 {
				_ = try decoder.append(byte)
			}
			try decoder.finish()
		}
	}

	@Test("SSE preserves safe backend error details")
	func errorEvent() {
		let error = ChatLLMAPIError(code: "provider_timeout", message: "Timed out", requestId: "request-1")
		#expect(throws: ChatLLMClientError.streamFailed(error)) {
			var decoder = ChatLLMStreamDecoder(provider: "openai", model: "test")
			for byte in "event: error\ndata: {\"error\":{\"code\":\"provider_timeout\",\"message\":\"Timed out\",\"request_id\":\"request-1\"}}\n\n".utf8 {
				_ = try decoder.append(byte)
			}
		}
	}

	@Test("Streaming transport sends opt-in and receives cumulative updates")
	func transport() async throws {
		let (client, session) = try makeClient(path: "success")
		defer { session.invalidateAndCancel() }
		let snapshots = SnapshotRecorder()
		let response = try await client.streamResponse(
			provider: "openai",
			model: "test",
			messages: [.init(role: .user, content: "Hello")],
			continuationId: nil
		) { text in
			await snapshots.append(text)
		}
		#expect(await snapshots.values == ["Hello", "Hello 🌎"])
		#expect(response.outputText == "Hello 🌎")
		#expect(response.requestId == "request-1")
		#expect(response.continuationId == nil)
	}

	@Test(
		"Streaming transport handles HTTP errors, wrong content type and dropped connections",
		arguments: ["http-error", "wrong-content", "truncated"]
	)
	func transportErrors(path: String) async throws {
		let (client, session) = try makeClient(path: path)
		defer { session.invalidateAndCancel() }
		await #expect(throws: ChatLLMClientError.self) {
			try await client.streamResponse(
				provider: "openai",
				model: "test",
				messages: [.init(role: .user, content: "Hello")],
				continuationId: nil
			) { _ in }
		}
	}

	@Test("Cancelling a stream unblocks a pending network read", .timeLimit(.minutes(1)))
	func cancellation() async throws {
		let (client, session) = try makeClient(path: "stall")
		defer { session.invalidateAndCancel() }
		let (ready, continuation) = AsyncStream.makeStream(of: Bool.self, bufferingPolicy: .bufferingNewest(1))
		let task = Task {
			try await client.streamResponse(
				provider: "openai",
				model: "test",
				messages: [.init(role: .user, content: "Hello")],
				continuationId: nil
			) { _ in
				continuation.yield(true)
			}
		}
		for await _ in ready { break }
		task.cancel()
		continuation.finish()
		do {
			_ = try await task.value
			Issue.record("Expected cancellation")
		} catch {
			#expect(error is CancellationError || (error as? URLError)?.code == .cancelled)
		}
	}

	private func makeClient(path: String) throws -> (ChatLLMClient, URLSession) {
		let config = URLSessionConfiguration.ephemeral
		config.protocolClasses = [StreamingURLProtocol.self]
		let session = URLSession(configuration: config)
		let configuration = try #require(
			ChatLLMConfiguration(endpoint: "https://example.test/\(path)", publishableKey: "sb_publishable_test")
		)
		return (ChatLLMClient(configuration: configuration, streamingSession: session), session)
	}
}

private actor SnapshotRecorder {
	private(set) var values = [String]()
	func append(_ text: String) { values.append(text) }
}

/// Per-request fixtures avoid shared mutable handlers when tests run in parallel.
private final class StreamingURLProtocol: URLProtocol {

	override class func canInit(with request: URLRequest) -> Bool { true }

	override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

	override func startLoading() {
		guard let url = request.url else {
			return
		}
		#expect(request.httpMethod == "POST")
		#expect(request.value(forHTTPHeaderField: "Accept") == "text/event-stream")
		#expect(request.value(forHTTPHeaderField: "apikey") == "sb_publishable_test")
		var body = request.httpBody ?? Data()
		if let stream = request.httpBodyStream {
			stream.open()
			defer {
				stream.close()
			}
			var buffer = [UInt8](repeating: 0, count: 1024)
			while stream.hasBytesAvailable {
				let count = stream.read(&buffer, maxLength: buffer.count)
				if count <= 0 {
					break
				}
				body.append(contentsOf: buffer.prefix(count))
			}
		}
		let payload = try? JSONSerialization.jsonObject(with: body) as? [String: Any]
		#expect(payload?["stream"] as? Bool == true)
		let path = url.lastPathComponent
		let httpError = path == "http-error"
		let response = HTTPURLResponse(url: url, statusCode: httpError ? 429 : 200, httpVersion: nil, headerFields: ["Content-Type": httpError || path == "wrong-content" ? "application/json" : "text/event-stream", "X-Request-Id": "request-1"])!
		client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
		if httpError {
			client?.urlProtocol(self, didLoad: Data("{\"error\":{\"code\":\"rate_limited\",\"message\":\"Slow down\",\"request_id\":\"request-1\"}}".utf8))
		} else {
			let delta = "event: delta\ndata: {\"text\":\"Hello\"}\n\n"
			let remainder = "event: delta\ndata: {\"text\":\" 🌎\"}\n\nevent: completed\ndata: {\"provider\":\"openai\",\"model\":\"test\"}\n\n"
			for byte in (delta + (path == "success" ? remainder : "")).utf8 {
				client?.urlProtocol(self, didLoad: Data([byte]))
			}
		}
		if path != "stall" {
			client?.urlProtocolDidFinishLoading(self)
		}
	}

	override func stopLoading() {}
}
