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
	@Test("Persisted messages are presented in transcript order")
	func ordersMessages() throws {
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: StubChatProvider(result: .success("Unused")),
			messages: [
				ChatMessage(sequence: 2, text: "Third", role: .assistant),
				ChatMessage(sequence: 0, text: "First", role: .user),
				ChatMessage(sequence: 1, text: "Second", role: .assistant)
			],
			modelContext: container.mainContext
		)

		#expect(viewModel.messages.map(\.text) == ["First", "Second", "Third"])
	}

	@Test("Conversation summaries reflect their transcript")
	func summarizesTranscript() throws {
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: StubChatProvider(result: .success("Unused")),
			messages: [
				ChatMessage(sequence: 2, text: "Latest", role: .assistant),
				ChatMessage(sequence: 0, text: "Welcome", role: .assistant),
				ChatMessage(sequence: 1, text: "My question", role: .user)
			],
			modelContext: container.mainContext
		)

		#expect(viewModel.title == "My question")
		#expect(viewModel.preview == "Latest")
		#expect(viewModel.hasUserMessages)
	}

	@Test("An empty conversation uses placeholder summaries")
	func summarizesEmptyTranscript() throws {
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: StubChatProvider(result: .success("Unused")),
			modelContext: container.mainContext
		)

		#expect(viewModel.title == "New Chat")
		#expect(viewModel.preview == "No messages yet")
		#expect(viewModel.hasUserMessages == false)
	}

	@Test("Blank drafts cannot be sent", arguments: ["", " ", "\n\t"])
	func rejectsBlankDraft(draft: String) async throws {
		let provider = StubChatProvider(result: .success("Unused"))
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: container.mainContext
		)
		viewModel.draft = draft

		await viewModel.sendMessage()

		#expect(viewModel.canSend == false)
		#expect(provider.receivedMessages.isEmpty)
		#expect(viewModel.messages.isEmpty)
		#expect(try container.mainContext.fetchCount(FetchDescriptor<ChatMessage>()) == 0)
	}

	@Test("An unavailable model cannot send a draft")
	func rejectsUnavailableModel() async throws {
		let provider = StubChatProvider(
			result: .success("Unused"),
			availability: .unavailable(message: "Unavailable")
		)
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: container.mainContext
		)
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(viewModel.canSend == false)
		#expect(provider.receivedMessages.isEmpty)
		#expect(viewModel.messages.isEmpty)
	}

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

	@Test("Cancellation keeps the user message without presenting an error")
	func handlesCancellation() async throws {
		let provider = StubChatProvider(result: .failure(CancellationError()))
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: container.mainContext
		)
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(viewModel.messages.map(\.text) == ["Hello"])
		#expect(viewModel.errorMessage == nil)
		#expect(viewModel.isResponding == false)
		#expect(try container.mainContext.fetchCount(FetchDescriptor<ChatMessage>()) == 1)
	}

	@Test("Dismissing an error clears it")
	func dismissesError() async throws {
		let container = try makeModelContainer()
		let viewModel = ChatViewModel(
			provider: StubChatProvider(result: .failure(TestError.responseFailed)),
			modelContext: container.mainContext
		)
		viewModel.draft = "Hello"
		await viewModel.sendMessage()
		try #require(viewModel.isShowingError)

		viewModel.isShowingError = false

		#expect(viewModel.errorMessage == nil)
		#expect(viewModel.isShowingError == false)
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
	let model: LanguageModel

	private let result: Result<String, any Error>

	let continuationId: String?

	private(set) var receivedMessages: [String] = []

	init(
		result: Result<String, any Error>,
		continuationId: String? = nil,
		availability: LanguageModelAvailability = .available
	) {
		self.model = LanguageModel(
			id: "test-model",
			displayName: "Test Model",
			providerId: "test-provider",
			providerName: "Test Provider",
			summary: "A model used in tests.",
			availability: availability
		)
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
