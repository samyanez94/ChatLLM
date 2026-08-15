//
//  OpenAIClient.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

import Foundation

/// Sends requests to the OpenAI Responses API.
nonisolated struct OpenAIClient: Sendable {
	private static let responsesURL = URL(string: "https://api.openai.com/v1/responses")!

	private let apiKey: String

	private let session: any URLSessionDataLoading

	private let endpoint: URL

	init(
		apiKey: String,
		session: any URLSessionDataLoading = URLSession.shared,
		endpoint: URL = Self.responsesURL
	) {
		self.apiKey = apiKey
		self.session = session
		self.endpoint = endpoint
	}

	/// Creates a text response, optionally continuing an earlier OpenAI response.
	/// - Parameters:
	///   - model: The OpenAI API model identifier.
	///   - input: The user's text input.
	///   - previousResponseID: The prior response identifier for multi-turn context.
	func createResponse(
		model: String,
		input: String,
		previousResponseID: String? = nil
	) async throws -> OpenAIResponse {
		let request = try makeRequest(
			model: model,
			input: input,
			previousResponseID: previousResponseID
		)
		let (data, response) = try await session.data(for: request)
		let decoder = JSONDecoder()

		guard let httpResponse = response as? HTTPURLResponse else {
			throw OpenAIClientError.invalidHTTPResponse
		}

		guard (200...299).contains(httpResponse.statusCode) else {
			let envelope = try? decoder.decode(ErrorEnvelope.self, from: data)
			throw OpenAIClientError.httpError(
				statusCode: httpResponse.statusCode,
				apiError: envelope?.error
			)
		}

		let payload: ResponsePayload
		do {
			payload = try decoder.decode(ResponsePayload.self, from: data)
		} catch {
			throw OpenAIClientError.invalidResponsePayload
		}

		let outputText = payload.output
			.flatMap(\.content)
			.filter { $0.type == "output_text" }
			.compactMap(\.text)
			.joined()

		guard outputText.isEmpty == false else {
			throw OpenAIClientError.missingOutputText
		}

		return OpenAIResponse(id: payload.id, outputText: outputText)
	}

	private func makeRequest(
		model: String,
		input: String,
		previousResponseID: String?
	) throws -> URLRequest {
		let payload = RequestPayload(
			model: model,
			input: input,
			previousResponseID: previousResponseID
		)
		var request = URLRequest(url: endpoint)
		request.httpMethod = "POST"
		request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
		request.setValue("application/json", forHTTPHeaderField: "Content-Type")
		request.httpBody = try JSONEncoder().encode(payload)
		return request
	}
}

extension OpenAIClient {

	fileprivate nonisolated struct RequestPayload: Encodable, Sendable {
		let model: String
		let input: String
		let previousResponseID: String?

		private enum CodingKeys: String, CodingKey {
			case model
			case input
			case previousResponseID = "previous_response_id"
		}
	}

	fileprivate nonisolated struct ResponsePayload: Decodable, Sendable {
		let id: String
		let output: [OutputItem]
	}

	fileprivate nonisolated struct OutputItem: Decodable, Sendable {
		let content: [ContentItem]

		private enum CodingKeys: String, CodingKey {
			case content
		}

		init(from decoder: any Decoder) throws {
			let container = try decoder.container(keyedBy: CodingKeys.self)
			content = try container.decodeIfPresent([ContentItem].self, forKey: .content) ?? []
		}
	}

	fileprivate nonisolated struct ContentItem: Decodable, Sendable {
		let type: String
		let text: String?
	}

	fileprivate nonisolated struct ErrorEnvelope: Decodable, Sendable {
		let error: OpenAIAPIError
	}
}
