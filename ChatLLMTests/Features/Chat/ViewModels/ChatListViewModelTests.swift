//
//  ChatListViewModelTests.swift
//  ChatLLMTests
//

import SwiftData
import Testing

@testable import ChatLLM

@MainActor
struct ChatListViewModelTests {
	@Test("Loading a saved chat restores its provider state")
	func restoresSavedChat() throws {
		let container = try makeChatListModelContainer()
		let context = container.mainContext
		let provider = StubRestoredChatProvider()
		let recorder = ProviderRestorationRecorder()
		let chat = Chat(
			providerId: provider.model.providerId,
			modelId: provider.model.id,
			continuationId: "response-1",
			messages: [
				ChatMessage(sequence: 0, text: "Hello", role: .user),
				ChatMessage(sequence: 1, text: "Hello back", role: .assistant)
			]
		)
		context.insert(chat)
		try context.save()
		context.rollback()

		let viewModel = ChatListViewModel(
			modelContext: context,
			providerFactory: StubRestoringProviderFactory(
				provider: provider,
				recorder: recorder
			)
		)

		#expect(viewModel.chats.map(\.id) == [chat.id])
		#expect(recorder.messageTexts == ["Hello", "Hello back"])
		#expect(recorder.continuationId == "response-1")
	}
}

@MainActor
private func makeChatListModelContainer() throws -> ModelContainer {
	try ModelContainer(
		for: Schema(versionedSchema: ChatSchemaV1.self),
		migrationPlan: ChatMigrationPlan.self,
		configurations: ModelConfiguration(isStoredInMemoryOnly: true)
	)
}

// MARK: - StubRestoredChatProvider

@MainActor
private final class StubRestoredChatProvider: ChatProviding {
	let model = LanguageModel(
		id: "test-model",
		displayName: "Test Model",
		providerId: "test-provider",
		providerName: "Test Provider",
		summary: "A model used in tests.",
		availability: .available
	)

	func generateReply(to message: String) async throws -> String {
		"Hello back"
	}
}

// MARK: - ProviderRestorationRecorder

@MainActor
private final class ProviderRestorationRecorder {
	var messageTexts: [String] = []
	var continuationId: String?
}

// MARK: - ProviderRestorationRecorder

@MainActor
private struct StubRestoringProviderFactory: ChatProviderCreating {
	let provider: StubRestoredChatProvider
	let recorder: ProviderRestorationRecorder

	var models: [LanguageModel] {
		[provider.model]
	}

	func makeProvider(for model: LanguageModel) -> (any ChatProviding)? {
		provider
	}

	func restoreProvider(
		for model: LanguageModel,
		messages: [ChatMessage],
		continuationId: String?
	) -> (any ChatProviding)? {
		recorder.messageTexts =
			messages
			.sorted { $0.sequence < $1.sequence }
			.map(\.text)
		recorder.continuationId = continuationId
		return provider
	}
}
