//
//  ChatListViewModelTests.swift
//  ChatLLMTests
//

import Foundation
import SwiftData
import Testing

@testable import ChatLLM

@MainActor
struct ChatListViewModelTests {
	@Test("Visible chats exclude empty conversations and show newest first")
	func filtersAndOrdersVisibleChats() throws {
		let container = try makeChatListModelContainer()
		let context = container.mainContext
		let provider = StubRestoredChatProvider()
		let older = makePersistedChat(
			provider: provider,
			text: "Older",
			updatedAt: Date(timeIntervalSince1970: 100)
		)
		let newer = makePersistedChat(
			provider: provider,
			text: "Newer",
			updatedAt: Date(timeIntervalSince1970: 200)
		)
		let empty = Chat(
			providerId: provider.model.providerId,
			modelId: provider.model.id,
			updatedAt: Date(timeIntervalSince1970: 300)
		)
		context.insert(older)
		context.insert(newer)
		context.insert(empty)
		try context.save()

		let viewModel = ChatListViewModel(
			modelContext: context,
			providerFactory: StubRestoringProviderFactory(provider: provider)
		)

		#expect(viewModel.chats.count == 3)
		#expect(viewModel.visibleChats.map(\.id) == [newer.id, older.id])
	}

	@Test("Creating a chat stores it and makes it discoverable")
	func createsChat() throws {
		let container = try makeChatListModelContainer()
		let provider = StubRestoredChatProvider()
		let viewModel = ChatListViewModel(
			modelContext: container.mainContext,
			providerFactory: StubRestoringProviderFactory(provider: provider)
		)

		let created = try #require(viewModel.createChat(using: provider.model))

		#expect(viewModel.chat(withId: created.id) === created)
		#expect(viewModel.chat(withId: UUID()) == nil)
		#expect(try container.mainContext.fetchCount(FetchDescriptor<Chat>()) == 1)
	}

	@Test("Unavailable and unsupported models cannot create chats")
	func rejectsUnusableModels() throws {
		let container = try makeChatListModelContainer()
		let provider = StubRestoredChatProvider()
		let factory = StubRestoringProviderFactory(
			provider: provider,
			allowsCreation: false
		)
		let viewModel = ChatListViewModel(
			modelContext: container.mainContext,
			providerFactory: factory
		)
		let unavailableModel = LanguageModel(
			id: "unavailable-model",
			displayName: "Unavailable",
			providerId: "test-provider",
			providerName: "Test Provider",
			summary: "Unavailable in this test.",
			availability: .unavailable(message: "Unavailable")
		)

		#expect(viewModel.createChat(using: unavailableModel) == nil)
		#expect(viewModel.createChat(using: provider.model) == nil)
		#expect(viewModel.chats.isEmpty)
		#expect(try container.mainContext.fetchCount(FetchDescriptor<Chat>()) == 0)
	}

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

	@Test("Loading skips chats for unsupported models")
	func skipsUnsupportedSavedChat() throws {
		let container = try makeChatListModelContainer()
		let context = container.mainContext
		context.insert(
			Chat(
				providerId: "removed-provider",
				modelId: "removed-model"
			)
		)
		try context.save()
		let provider = StubRestoredChatProvider()

		let viewModel = ChatListViewModel(
			modelContext: context,
			providerFactory: StubRestoringProviderFactory(provider: provider)
		)

		#expect(viewModel.chats.isEmpty)
		#expect(try context.fetchCount(FetchDescriptor<Chat>()) == 1)
	}

	@Test("Removing empty chats preserves conversations with user messages")
	func removesEmptyChats() throws {
		let container = try makeChatListModelContainer()
		let context = container.mainContext
		let provider = StubRestoredChatProvider()
		let populated = makePersistedChat(
			provider: provider,
			text: "Keep me",
			updatedAt: Date(timeIntervalSince1970: 100)
		)
		let empty = Chat(
			providerId: provider.model.providerId,
			modelId: provider.model.id
		)
		context.insert(populated)
		context.insert(empty)
		try context.save()
		let viewModel = ChatListViewModel(
			modelContext: context,
			providerFactory: StubRestoringProviderFactory(provider: provider)
		)

		viewModel.removeEmptyChats()

		#expect(viewModel.chats.map(\.id) == [populated.id])
		#expect(try context.fetch(FetchDescriptor<Chat>()).map(\.id) == [populated.id])
	}

	@Test("Removing a visible offset deletes the chat in visible ordering")
	func removesVisibleChatAtOffset() throws {
		let container = try makeChatListModelContainer()
		let context = container.mainContext
		let provider = StubRestoredChatProvider()
		let older = makePersistedChat(
			provider: provider,
			text: "Older",
			updatedAt: Date(timeIntervalSince1970: 100)
		)
		let newer = makePersistedChat(
			provider: provider,
			text: "Newer",
			updatedAt: Date(timeIntervalSince1970: 200)
		)
		context.insert(older)
		context.insert(newer)
		try context.save()
		let viewModel = ChatListViewModel(
			modelContext: context,
			providerFactory: StubRestoringProviderFactory(provider: provider)
		)

		viewModel.removeChats(atOffsets: IndexSet(integer: 0))

		#expect(viewModel.chats.map(\.id) == [older.id])
		#expect(try context.fetch(FetchDescriptor<Chat>()).map(\.id) == [older.id])
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

@MainActor
private func makePersistedChat(
	provider: StubRestoredChatProvider,
	text: String,
	updatedAt: Date
) -> Chat {
	Chat(
		providerId: provider.model.providerId,
		modelId: provider.model.id,
		updatedAt: updatedAt,
		messages: [
			ChatMessage(
				sequence: 0,
				text: text,
				role: .user,
				createdAt: updatedAt
			)
		]
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

	var recorder = ProviderRestorationRecorder()

	var allowsCreation = true

	var models: [LanguageModel] {
		[provider.model]
	}

	func makeProvider(for model: LanguageModel) -> (any ChatProviding)? {
		allowsCreation ? provider : nil
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
