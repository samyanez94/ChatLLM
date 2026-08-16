//
//  ChatLLMChatServiceTests.swift
//  ChatAppTests
//
//  Created by Samuel Yanez on 8/16/26.
//

import Testing

@testable import ChatApp

@MainActor
struct ChatLLMChatServiceTests {
	@Test("The first reply uses OpenAI without a continuation identifier")
	func firstReply() async throws {
		let client = StubChatLLMClient(
			responses: [makeResponse(id: "response-1", text: "First reply")]
		)
		let service = ChatLLMChatService(client: client)

		let reply = try await service.generateReply(to: "Hello")
		let requests = await client.recordedRequests

		#expect(reply == "First reply")
		#expect(
			requests == [
				.init(
					provider: "openai",
					model: OpenAIModelCatalog.lunaId,
					input: "Hello",
					continuationId: nil
				)
			]
		)
	}

	@Test("A later reply continues from the last successful response")
	func continuedReply() async throws {
		let client = StubChatLLMClient(
			responses: [
				makeResponse(id: "response-1", text: "First reply"),
				makeResponse(id: "response-2", text: "Second reply")
			]
		)
		let service = ChatLLMChatService(client: client)

		_ = try await service.generateReply(to: "First")
		let reply = try await service.generateReply(to: "Second")
		let requests = await client.recordedRequests

		#expect(reply == "Second reply")
		#expect(requests.map(\.continuationId) == [nil, "response-1"])
	}

	@Test("A failed reply does not replace the last continuation identifier")
	func failedReplyPreservesContinuation() async throws {
		let client = StubChatLLMClient(
			results: [
				.success(makeResponse(id: "response-1", text: "First reply")),
				.failure(TestError.requestFailed),
				.success(makeResponse(id: "response-2", text: "Third reply"))
			]
		)
		let service = ChatLLMChatService(client: client)

		_ = try await service.generateReply(to: "First")
		await #expect(throws: TestError.requestFailed) {
			try await service.generateReply(to: "Second")
		}
		_ = try await service.generateReply(to: "Third")
		let requests = await client.recordedRequests

		#expect(requests.map(\.continuationId) == [nil, "response-1", "response-1"])
	}

	private func makeResponse(id: String, text: String) -> ChatLLMResponse {
		ChatLLMResponse(
			provider: "openai",
			model: OpenAIModelCatalog.lunaId,
			continuationId: id,
			outputText: text,
			requestId: nil
		)
	}
}

private actor StubChatLLMClient: ChatLLMResponseCreating {
	struct Request: Equatable, Sendable {
		let provider: String
		let model: String
		let input: String
		let continuationId: String?
	}

	private(set) var recordedRequests: [Request] = []
	private var results: [Result<ChatLLMResponse, any Error>]

	init(responses: [ChatLLMResponse]) {
		self.results = responses.map(Result.success)
	}

	init(results: [Result<ChatLLMResponse, any Error>]) {
		self.results = results
	}

	func createResponse(
		provider: String,
		model: String,
		input: String,
		continuationId: String?
	) async throws -> ChatLLMResponse {
		recordedRequests.append(
			Request(
				provider: provider,
				model: model,
				input: input,
				continuationId: continuationId
			)
		)
		return try results.removeFirst().get()
	}
}

private enum TestError: Error {
	case requestFailed
}
