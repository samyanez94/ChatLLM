//
//  ChatListViewModelTests.swift
//  ChatLLMTests
//

import Foundation
import Testing

@testable import ChatLLM

// MARK: - ChatListViewModelTests

@MainActor
struct ChatListViewModelTests {
	@Test("A chat becomes visible after its first message and can be removed")
	func managesChatLifecycle() async throws {
		let provider = StubChatProvider()
		let factory = StubChatProviderFactory(provider: provider)
		let viewModel = ChatListViewModel(providerFactory: factory)

		let chat = try #require(viewModel.createChat(using: provider.model))
		#expect(viewModel.visibleChats.isEmpty)

		chat.draft = "Hello"
		await chat.sendMessage()
		#expect(viewModel.visibleChats.map(\.id) == [chat.id])

		viewModel.removeChats(atOffsets: IndexSet(integer: 0))
		#expect(viewModel.chats.isEmpty)
	}
}

// MARK: - StubChatProvider

@MainActor
private final class StubChatProvider: ChatProviding {
	let model = ChatModel(
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

// MARK: - StubChatProviderFactory

@MainActor
private struct StubChatProviderFactory: ChatProviderCreating {
	let provider: StubChatProvider

	var models: [ChatModel] {
		[provider.model]
	}

	func makeProvider(for model: ChatModel) -> (any ChatProviding)? {
		model.providerId == provider.model.providerId && model.id == provider.model.id
			? provider : nil
	}
}
