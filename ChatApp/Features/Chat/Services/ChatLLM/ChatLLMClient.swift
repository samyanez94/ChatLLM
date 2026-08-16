//
//  ChatLLMClient.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/16/26.
//

import Foundation

/// Sends provider-neutral requests to the hosted ChatLLM API.
nonisolated struct ChatLLMClient: ChatLLMResponseCreating, Sendable {
	private let configuration: ChatLLMConfiguration
	private let session: any URLSessionDataLoading

	init(
		configuration: ChatLLMConfiguration,
		session: any URLSessionDataLoading = URLSession.shared
	) {
		self.configuration = configuration
		self.session = session
	}

	/// Creates a response, optionally continuing an earlier provider conversation.
	func createResponse(
		provider: String,
		model: String,
		input: String,
		continuationId: String? = nil
	) async throws -> ChatLLMResponse {
		let request = try makeRequest(
			provider: provider,
			model: model,
			input: input,
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
			payload.continuationId.isEmpty == false,
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

	private func makeRequest(
		provider: String,
		model: String,
		input: String,
		continuationId: String?
	) throws -> URLRequest {
		let payload = RequestPayload(
			provider: provider,
			model: model,
			input: input,
			continuationId: continuationId
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
		let input: String
		let continuationId: String?

		private enum CodingKeys: String, CodingKey {
			case provider
			case model
			case input
			case continuationId = "continuation_id"
		}
	}

	private nonisolated struct ResponsePayload: Decodable, Sendable {
		let provider: String
		let model: String
		let continuationId: String
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
