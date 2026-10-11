//
//  ChatLLMClient.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

import Foundation

/// Sends provider-neutral requests to the hosted ChatLLM API.
nonisolated struct ChatLLMClient: ChatLLMResponseCreating, Sendable {

	private let configuration: ChatLLMConfiguration

	private let session: any URLSessionDataLoading

	private let streamingSession: URLSession

	init(
		configuration: ChatLLMConfiguration,
		session: any URLSessionDataLoading = URLSession.shared,
		streamingSession: URLSession = .shared
	) {
		self.configuration = configuration
		self.session = session
		self.streamingSession = streamingSession
	}

	/// Creates a response, optionally continuing an earlier provider conversation.
	func createResponse(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String? = nil
	) async throws -> ChatLLMResponse {
		let request = try makeRequest(
			provider: provider,
			model: model,
			messages: messages,
			continuationId: continuationId
		)
		let (data, response) = try await session.data(for: request)
		guard let httpResponse = response as? HTTPURLResponse else {
			throw ChatLLMClientError.invalidHTTPResponse
		}
		guard (200...299).contains(httpResponse.statusCode) else {
			if httpResponse.statusCode == 401 {
				throw ChatLLMClientError.invalidAPIKey
			}
			let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
			throw ChatLLMClientError.requestFailed(
				statusCode: httpResponse.statusCode,
				apiError: envelope?.error
			)
		}
		let payload: ResponsePayload
		do {
			payload = try JSONDecoder().decode(ResponsePayload.self, from: data)
		} catch {
			throw ChatLLMClientError.invalidResponsePayload
		}
		guard payload.provider == provider,
			payload.model == model,
			payload.continuationId?.isEmpty != true,
			payload.outputText.isEmpty == false
		else {
			throw ChatLLMClientError.invalidResponsePayload
		}
		return ChatLLMResponse(
			provider: payload.provider,
			model: payload.model,
			continuationId: payload.continuationId,
			outputText: payload.outputText,
			requestId: httpResponse.value(forHTTPHeaderField: "X-Request-Id")
		)
	}

	/// Consumes the stream in the caller's task, with no detached producer or token queue.
	func streamResponse(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String?,
		onUpdate: @Sendable (String) async -> Void
	) async throws -> ChatLLMResponse {
		var request = try makeRequest(
			provider: provider,
			model: model,
			messages: messages,
			continuationId: continuationId,
			stream: true
		)
		request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
		request.timeoutInterval = 75
		let (bytes, response) = try await streamingSession.bytes(for: request)
		defer {
			bytes.task.cancel()
		}
		return try await withTaskCancellationHandler {
			guard let http = response as? HTTPURLResponse else {
				throw ChatLLMClientError.invalidHTTPResponse
			}
			guard (200...299).contains(http.statusCode) else {
				if http.statusCode == 401 {
					throw ChatLLMClientError.invalidAPIKey
				}
				var data = Data()
				for try await byte in bytes {
					try Task.checkCancellation()
					guard data.count < 65_536 else { break }
					data.append(byte)
				}
				let envelope = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
				throw ChatLLMClientError.requestFailed(
					statusCode: http.statusCode,
					apiError: envelope?.error
				)
			}
			guard http.mimeType?.lowercased() == "text/event-stream" else {
				throw ChatLLMClientError.invalidResponsePayload
			}
			var decoder = ChatLLMStreamDecoder(provider: provider, model: model)
			for try await byte in bytes {
				try Task.checkCancellation()
				if try decoder.append(byte) {
					await onUpdate(decoder.text)
				}
				if decoder.isComplete {
					break
				}
			}
			try Task.checkCancellation()
			try decoder.finish()
			return ChatLLMResponse(
				provider: provider,
				model: model,
				continuationId: nil,
				outputText: decoder.text,
				requestId: http.value(forHTTPHeaderField: "X-Request-Id")
			)
		} onCancel: {
			bytes.task.cancel()
		}
	}

	private func makeRequest(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String?,
		stream: Bool? = nil
	) throws -> URLRequest {
		let payload = RequestPayload(
			provider: provider,
			model: model,
			messages: messages,
			continuationId: continuationId,
			stream: stream
		)
		var request = URLRequest(url: configuration.endpoint)
		request.httpMethod = "POST"
		request.setValue(configuration.publishableKey, forHTTPHeaderField: "apikey")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(payload)
		return request
	}
}

extension ChatLLMClient {

	private nonisolated struct RequestPayload: Encodable, Sendable {
		let provider: String
		let model: String
		let messages: [ChatLLMRequestMessage]
		let continuationId: String?
		let stream: Bool?

		private enum CodingKeys: String, CodingKey {
			case provider
			case model
			case messages
			case stream
			case continuationId = "continuation_id"
		}
	}

	private nonisolated struct ResponsePayload: Decodable, Sendable {
		let provider: String
		let model: String
		let continuationId: String?
		let outputText: String

		private enum CodingKeys: String, CodingKey {
			case provider
			case model
			case continuationId = "continuation_id"
			case outputText = "output_text"
		}
	}

	private nonisolated struct ErrorEnvelope: Decodable, Sendable {
		let error: ChatLLMAPIError
	}
}
