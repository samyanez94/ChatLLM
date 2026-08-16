//
//  ChatLLMClientTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 8/16/26.
//

import Foundation
import Testing

@testable import ChatLLM

struct ChatLLMClientTests {
	@Test("A first response sends the ChatLLM contract fields")
	func firstResponseRequest() async throws {
		let session = ChatLLMDataLoaderStub(
			data: successData,
			response: try httpResponse(statusCode: 200)
		)
		let client = try makeClient(session: session)

		_ = try await client.createResponse(
			provider: "openai",
			model: "gpt-5.6-luna",
			input: "Hello"
		)

		let request = try #require(await session.lastRequest)
		#expect(
			request.url?.absoluteString
				== "https://example.supabase.co/functions/v1/chat"
		)
		#expect(request.httpMethod == "POST")
		#expect(
			request.value(forHTTPHeaderField: "apikey")
				== "sb_publishable_example"
		)
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

		let body = try #require(request.httpBody)
		let json = try #require(
			JSONSerialization.jsonObject(with: body) as? [String: String]
		)
		#expect(json["provider"] == "openai")
		#expect(json["model"] == "gpt-5.6-luna")
		#expect(json["input"] == "Hello")
		#expect(json["continuation_id"] == nil)
		#expect(String(decoding: body, as: UTF8.self).contains("sb_publishable_example") == false)
	}

	@Test("A continued response includes the continuation identifier")
	func continuedResponseRequest() async throws {
		let session = ChatLLMDataLoaderStub(
			data: successData,
			response: try httpResponse(statusCode: 200)
		)
		let client = try makeClient(session: session)

		_ = try await client.createResponse(
			provider: "openai",
			model: "gpt-5.6-luna",
			input: "Continue",
			continuationId: "resp_previous"
		)

		let request = try #require(await session.lastRequest)
		let body = try #require(request.httpBody)
		let json = try #require(
			JSONSerialization.jsonObject(with: body) as? [String: String]
		)
		#expect(json["continuation_id"] == "resp_previous")
	}

	@Test("A valid ChatLLM response is decoded")
	func decodesResponse() async throws {
		let session = ChatLLMDataLoaderStub(
			data: successData,
			response: try httpResponse(
				statusCode: 200,
				headerFields: ["X-Request-Id": "request-123"]
			)
		)
		let client = try makeClient(session: session)

		let response = try await client.createResponse(
			provider: "openai",
			model: "gpt-5.6-luna",
			input: "Hello"
		)

		#expect(
			response
				== ChatLLMResponse(
					provider: "openai",
					model: "gpt-5.6-luna",
					continuationId: "resp_123",
					outputText: "Hello",
					requestId: "request-123"
				)
		)
	}

	@Test("A contract error is preserved")
	func decodesAPIError() async throws {
		let data = Data(
			"""
			{
			  "error": {
			    "code": "unsupported_model",
			    "message": "Unsupported model.",
			    "request_id": "request-123"
			  }
			}
			"""
			.utf8
		)
		let session = ChatLLMDataLoaderStub(
			data: data,
			response: try httpResponse(statusCode: 422)
		)
		let client = try makeClient(session: session)

		await #expect(
			throws: ChatLLMClientError.requestFailed(
				statusCode: 422,
				apiError: ChatLLMAPIError(
					code: "unsupported_model",
					message: "Unsupported model.",
					requestId: "request-123"
				)
			)
		) {
			try await client.createResponse(
				provider: "openai",
				model: "example-model",
				input: "Hello"
			)
		}
	}

	@Test("A gateway authentication error maps to an invalid API key")
	func mapsGatewayAuthenticationError() async throws {
		let session = ChatLLMDataLoaderStub(
			data: Data(#"{"message":"Invalid credentials","code":"INVALID_CREDENTIALS"}"#.utf8),
			response: try httpResponse(statusCode: 401)
		)
		let client = try makeClient(session: session)

		await #expect(throws: ChatLLMClientError.invalidAPIKey) {
			try await client.createResponse(
				provider: "openai",
				model: "gpt-5.6-luna",
				input: "Hello"
			)
		}
	}

	@Test("A malformed success payload is rejected")
	func rejectsMalformedPayload() async throws {
		let session = ChatLLMDataLoaderStub(
			data: Data("{}".utf8),
			response: try httpResponse(statusCode: 200)
		)
		let client = try makeClient(session: session)

		await #expect(throws: ChatLLMClientError.invalidResponsePayload) {
			try await client.createResponse(
				provider: "openai",
				model: "gpt-5.6-luna",
				input: "Hello"
			)
		}
	}

	@Test("A response for a different model is rejected")
	func rejectsMismatchedResponse() async throws {
		let data = Data(
			"""
			{
			  "provider": "openai",
			  "model": "example-model",
			  "continuation_id": "resp_123",
			  "output_text": "Hello"
			}
			"""
			.utf8
		)
		let session = ChatLLMDataLoaderStub(
			data: data,
			response: try httpResponse(statusCode: 200)
		)
		let client = try makeClient(session: session)

		await #expect(throws: ChatLLMClientError.invalidResponsePayload) {
			try await client.createResponse(
				provider: "openai",
				model: "gpt-5.6-luna",
				input: "Hello"
			)
		}
	}

	private var successData: Data {
		Data(
			"""
			{
			  "provider": "openai",
			  "model": "gpt-5.6-luna",
			  "continuation_id": "resp_123",
			  "output_text": "Hello"
			}
			"""
			.utf8
		)
	}

	private func makeClient(
		session: any URLSessionDataLoading
	) throws -> ChatLLMClient {
		let configuration = try #require(
			ChatLLMConfiguration(
				endpoint: "https://example.supabase.co/functions/v1/chat",
				publishableKey: "sb_publishable_example"
			)
		)
		return ChatLLMClient(configuration: configuration, session: session)
	}

	private func httpResponse(
		statusCode: Int,
		headerFields: [String: String]? = nil
	) throws -> HTTPURLResponse {
		let url = try #require(
			URL(string: "https://example.supabase.co/functions/v1/chat")
		)
		return try #require(
			HTTPURLResponse(
				url: url,
				statusCode: statusCode,
				httpVersion: nil,
				headerFields: headerFields
			)
		)
	}
}

// MARK: - ChatLLMDataLoaderStub

private actor ChatLLMDataLoaderStub: URLSessionDataLoading {
	private let data: Data
	private let response: URLResponse

	private(set) var lastRequest: URLRequest?

	init(data: Data, response: URLResponse) {
		self.data = data
		self.response = response
	}

	func data(for request: URLRequest) async throws -> (Data, URLResponse) {
		lastRequest = request
		return (data, response)
	}
}
