//
//  OpenAIClientTests.swift
//  ChatAppTests
//
//  Created by Samuel Yanez on 8/15/26.
//

import Foundation
import Testing

@testable import ChatApp

@MainActor
struct OpenAIClientTests {

	@Test("A first response sends the required request fields")
	func firstResponseRequest() async throws {
		let session = URLSessionDataLoaderStub(
			data: successData,
			response: httpResponse(statusCode: 200)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		_ = try await client.createResponse(
			model: OpenAIModelCatalog.lunaId,
			input: "Hello"
		)

		let request = try #require(await session.lastRequest)
		#expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
		#expect(request.httpMethod == "POST")
		#expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer test-api-key")
		#expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

		let body = try #require(request.httpBody)
		let json = try #require(
			JSONSerialization.jsonObject(with: body) as? [String: String]
		)
		#expect(json["model"] == "gpt-5.6-luna")
		#expect(json["input"] == "Hello")
		#expect(json["previous_response_id"] == nil)
		#expect(String(decoding: body, as: UTF8.self).contains("test-api-key") == false)
	}

	@Test("A continued response includes the previous response identifier")
	func continuedResponseRequest() async throws {
		let session = URLSessionDataLoaderStub(
			data: successData,
			response: httpResponse(statusCode: 200)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		_ = try await client.createResponse(
			model: OpenAIModelCatalog.lunaId,
			input: "Continue",
			previousResponseID: "resp_previous"
		)

		let request = await session.lastRequest
		let body = try #require(request?.httpBody)
		let json = try #require(
			JSONSerialization.jsonObject(with: body) as? [String: String]
		)
		#expect(json["previous_response_id"] == "resp_previous")
	}

	@Test("Text is collected from every output text item")
	func decodesOutputText() async throws {
		let data = Data(
			"""
			{
			  "id": "resp_123",
			  "output": [
			    { "type": "reasoning" },
			    {
			      "type": "message",
			      "content": [
			        { "type": "output_text", "text": "Hello" },
			        { "type": "refusal", "refusal": "ignored" },
			        { "type": "output_text", "text": " world" }
			      ]
			    }
			  ]
			}
			"""
			.utf8
		)
		let session = URLSessionDataLoaderStub(
			data: data,
			response: httpResponse(statusCode: 200)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		let response = try await client.createResponse(model: "gpt-5.6-luna", input: "Hi")

		#expect(response == OpenAIResponse(id: "resp_123", outputText: "Hello world"))
	}

	@Test("OpenAI error details are preserved")
	func decodesAPIError() async throws {
		let data = Data(
			"""
			{
			  "error": {
			    "message": "Incorrect API key provided",
			    "type": "invalid_request_error",
			    "param": null,
			    "code": "invalid_api_key"
			  }
			}
			"""
			.utf8
		)
		let session = URLSessionDataLoaderStub(
			data: data,
			response: httpResponse(statusCode: 401)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		await #expect(
			throws: OpenAIClientError.httpError(
				statusCode: 401,
				apiError: OpenAIAPIError(
					message: "Incorrect API key provided",
					type: "invalid_request_error",
					parameter: nil,
					code: "invalid_api_key"
				)
			)
		) {
			try await client.createResponse(model: "gpt-5.6-luna", input: "Hi")
		}
	}

	@Test("A successful malformed payload is rejected")
	func rejectsMalformedPayload() async throws {
		let session = URLSessionDataLoaderStub(
			data: Data("{}".utf8),
			response: httpResponse(statusCode: 200)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		await #expect(throws: OpenAIClientError.invalidResponsePayload) {
			try await client.createResponse(model: "gpt-5.6-luna", input: "Hi")
		}
	}

	@Test("A response without output text is rejected")
	func rejectsMissingText() async throws {
		let data = Data(
			"""
			{
			  "id": "resp_123",
			  "output": [{ "type": "reasoning" }]
			}
			"""
			.utf8
		)
		let session = URLSessionDataLoaderStub(
			data: data,
			response: httpResponse(statusCode: 200)
		)
		let client = OpenAIClient(apiKey: "test-api-key", session: session)

		await #expect(throws: OpenAIClientError.missingOutputText) {
			try await client.createResponse(model: "gpt-5.6-luna", input: "Hi")
		}
	}

	private var successData: Data {
		Data(
			"""
			{
			  "id": "resp_123",
			  "output": [
			    {
			      "type": "message",
			      "content": [{ "type": "output_text", "text": "Hello" }]
			    }
			  ]
			}
			"""
			.utf8
		)
	}

	private func httpResponse(statusCode: Int) -> HTTPURLResponse {
		HTTPURLResponse(
			url: URL(string: "https://api.openai.com/v1/responses")!,
			statusCode: statusCode,
			httpVersion: nil,
			headerFields: nil
		)!
	}
}

// MARK: - URLSessionDataLoaderStub

private actor URLSessionDataLoaderStub: URLSessionDataLoading {
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
