//
//  ChatLLMChatServiceTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 8/16/26.
//

import Testing

@testable import ChatLLM

@MainActor
struct ChatLLMChatServiceTests {
	@Test(
		"The first reply forwards the selected OpenAI model",
		arguments: OpenAIModelCatalog.modelIds
	)
	func firstReply(modelId: LanguageModel.ID) async throws {
		let client = StubChatLLMClient(
			responses: [
				makeResponse(id: "response-1", text: "First reply", modelId: modelId)
			]
		)
		let service = ChatLLMChatService(
			client: client,
			model: try makeModel(id: modelId)
		)

		let reply = try await service.generateReply(to: "Hello")
		let requests = await client.recordedRequests

		#expect(reply == "First reply")
		#expect(
			requests == [
				.init(
					provider: "openai",
					model: modelId,
					messages: [.init(role: .user, content: "Hello")],
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
		let service = ChatLLMChatService(
			client: client,
			model: try makeModel()
		)

		_ = try await service.generateReply(to: "First")
		let reply = try await service.generateReply(to: "Second")
		let requests = await client.recordedRequests

		#expect(reply == "Second reply")
		#expect(requests.map(\.continuationId) == [nil, "response-1"])
		#expect(
			requests.last?.messages == [
				.init(role: .user, content: "First"),
				.init(role: .assistant, content: "First reply"),
				.init(role: .user, content: "Second")
			]
		)
	}

	@Test("A restored conversation uses its persisted continuation identifier")
	func restoredConversationContinues() async throws {
		let client = StubChatLLMClient(
			responses: [makeResponse(id: "response-2", text: "Restored reply")]
		)
		let service = ChatLLMChatService(
			client: client,
			model: try makeModel(),
			messages: [
				.init(role: .user, content: "Original"),
				.init(role: .assistant, content: "Original reply")
			],
			continuationId: "response-1"
		)

		let reply = try await service.generateReply(to: "Continue")
		let requests = await client.recordedRequests

		#expect(reply == "Restored reply")
		#expect(requests.map(\.continuationId) == ["response-1"])
		#expect(requests.first?.messages.count == 3)
		#expect(service.continuationId == "response-2")
	}

	@Test("A restored Claude conversation sends its persisted transcript")
	func restoredClaudeConversation() async throws {
		let client = StubChatLLMClient(
			responses: [
				ChatLLMResponse(
					provider: AnthropicModelCatalog.providerId,
					model: AnthropicModelCatalog.sonnetId,
					continuationId: nil,
					outputText: "Restored reply",
					requestId: nil
				)
			]
		)
		let persistedMessages = [
			ChatMessage(sequence: 1, text: "Earlier reply", role: .assistant),
			ChatMessage(sequence: 0, text: "Earlier", role: .user)
		]
		let model = try #require(
			AnthropicModelCatalog.model(
				withId: AnthropicModelCatalog.sonnetId,
				isConfigured: true
			)
		)
		let service = ChatLLMChatService(
			client: client,
			model: model,
			persistedMessages: persistedMessages
		)

		_ = try await service.generateReply(to: "Continue")
		let request = try #require(await client.recordedRequests.first)

		#expect(
			request.messages == [
				.init(role: .user, content: "Earlier"),
				.init(role: .assistant, content: "Earlier reply"),
				.init(role: .user, content: "Continue")
			]
		)
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
		let service = ChatLLMChatService(
			client: client,
			model: try makeModel()
		)

		_ = try await service.generateReply(to: "First")
		await #expect(throws: TestError.requestFailed) {
			try await service.generateReply(to: "Second")
		}
		_ = try await service.generateReply(to: "Third")
		let requests = await client.recordedRequests

		#expect(requests.map(\.continuationId) == [nil, "response-1", "response-1"])
		#expect(
			requests.last?.messages == [
				.init(role: .user, content: "First"),
				.init(role: .assistant, content: "First reply"),
				.init(role: .user, content: "Third")
			]
		)
	}

	private func makeModel(
		id: LanguageModel.ID = OpenAIModelCatalog.lunaId
	) throws -> LanguageModel {
		try #require(OpenAIModelCatalog.model(withId: id, isConfigured: true))
	}

	private func makeResponse(
		id: String,
		text: String,
		modelId: LanguageModel.ID = OpenAIModelCatalog.lunaId
	) -> ChatLLMResponse {
		ChatLLMResponse(
			provider: "openai",
			model: modelId,
			continuationId: id,
			outputText: text,
			requestId: nil
		)
	}
}

// MARK: - StubChatLLMClient

private actor StubChatLLMClient: ChatLLMResponseCreating {
	struct Request: Equatable, Sendable {
		let provider: String
		let model: String
		let messages: [ChatLLMRequestMessage]
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
		messages: [ChatLLMRequestMessage],
		continuationId: String?
	) async throws -> ChatLLMResponse {
		recordedRequests.append(
			Request(
				provider: provider,
				model: model,
				messages: messages,
				continuationId: continuationId
			)
		)
		return try results.removeFirst().get()
	}
}

// MARK: - TestError

private enum TestError: Error {
	case requestFailed
}
