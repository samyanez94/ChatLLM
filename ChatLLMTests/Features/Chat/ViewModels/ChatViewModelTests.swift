//
//  ChatViewModelTests.swift
//  ChatLLMTests
//

import SwiftData
import Testing

@testable import ChatLLM

// MARK: - ChatViewModelTests

@MainActor
struct ChatViewModelTests {
	@Test("Sending a message appends the user message and reply")
	func sendsMessage() async throws {
		let provider = StubChatProvider(result: .success("Hello back"))
		let container = try makeModelContainer()
		let modelContext = container.mainContext
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: modelContext
		)
		let chat = viewModel.chat
		viewModel.draft = "  Hello  "

		await viewModel.sendMessage()

		#expect(provider.receivedMessages == ["Hello"])
		#expect(viewModel.messages.map(\.text) == ["Hello", "Hello back"])
		#expect(viewModel.messages.map(\.sequence) == [0, 1])
		#expect(chat.messages.map(\.text).sorted() == ["Hello", "Hello back"].sorted())
		#expect(chat.messages.allSatisfy { $0.chat === chat })
		#expect(viewModel.draft.isEmpty)
		#expect(viewModel.isResponding == false)
		#expect(viewModel.errorMessage == nil)
		#expect(try modelContext.fetchCount(FetchDescriptor<Chat>()) == 1)
		#expect(try modelContext.fetchCount(FetchDescriptor<ChatMessage>()) == 2)
	}

	@Test("A failed response keeps the user message and presents an error")
	func handlesFailedResponse() async throws {
		let provider = StubChatProvider(result: .failure(TestError.responseFailed))
		let container = try makeModelContainer()
		let modelContext = container.mainContext
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: modelContext
		)
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(viewModel.messages.map(\.text) == ["Hello"])
		#expect(
			viewModel.errorMessage
				== "The response couldn’t be generated. Please try again."
		)
		#expect(viewModel.isResponding == false)
		#expect(try modelContext.fetchCount(FetchDescriptor<ChatMessage>()) == 1)
	}

	@Test("A reply persists the provider continuation identifier")
	func persistsContinuationIdentifier() async throws {
		let provider = StubChatProvider(
			result: .success("Hello back"),
			continuationId: "response-1"
		)
		let container = try makeModelContainer()
		let modelContext = container.mainContext
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: modelContext
		)
		viewModel.draft = "Hello"

		await viewModel.sendMessage()
		modelContext.rollback()

		let chat = try #require(modelContext.fetch(FetchDescriptor<Chat>()).first)
		#expect(chat.continuationId == "response-1")
	}

	@Test("A backend error preserves its message and request identifier")
	func preservesBackendError() async throws {
		let apiError = ChatLLMAPIError(
			code: "rate_limited",
			message: "The provider rate limit has been exceeded.",
			requestId: "request-123"
		)
		let provider = StubChatProvider(
			result: .failure(
				ChatLLMClientError.requestFailed(statusCode: 429, apiError: apiError)
			)
		)
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: container.mainContext
		)
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(
			viewModel.errorMessage
				== "The provider rate limit has been exceeded.\n\nRequest ID: request-123"
		)
	}
}

@MainActor
private func makeModelContainer() throws -> ModelContainer {
	try ModelContainer(
		for: Schema(versionedSchema: ChatSchemaV1.self),
		migrationPlan: ChatMigrationPlan.self,
		configurations: ModelConfiguration(isStoredInMemoryOnly: true)
	)
}

// MARK: - StubChatProvider

@MainActor
private final class StubChatProvider: ChatProviding {
	let model = LanguageModel(
		id: "test-model",
		displayName: "Test Model",
		providerId: "test-provider",
		providerName: "Test Provider",
		summary: "A model used in tests.",
		availability: .available
	)

	private let result: Result<String, any Error>

	let continuationId: String?

	private(set) var receivedMessages: [String] = []

	init(
		result: Result<String, any Error>,
		continuationId: String? = nil
	) {
		self.result = result
		self.continuationId = continuationId
	}

	func generateReply(to message: String) async throws -> String {
		receivedMessages.append(message)
		return try result.get()
	}
}

// MARK: - TestError

private enum TestError: Error {
	case responseFailed
}
