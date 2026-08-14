//
//  ChatListViewModel.swift
//  ChatListViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Observation

/// Manages the chats created during the current app session.
@Observable
final class ChatListViewModel {
	/// The chats in the order they were created, newest first.
	private(set) var chats: [ChatViewModel]

	private let providerFactory: any ChatProviderCreating

	init(
		providerFactory: any ChatProviderCreating = ChatProviderFactory(),
		chats: [ChatViewModel] = []
	) {
		self.providerFactory = providerFactory
		self.chats = chats
	}

	/// The models that can be used to create a chat.
	var models: [ChatModel] {
		providerFactory.models
	}

	/// Creates and stores a chat with a fresh provider session.
	/// - Parameter model: The model to assign to the conversation.
	/// - Returns: The created chat, or `nil` when the model cannot be used.
	@discardableResult
	func createChat(using model: ChatModel) -> ChatViewModel? {
		guard
			model.availability.isAvailable,
			let provider = providerFactory.makeProvider(for: model.id),
			provider.model.availability.isAvailable
		else {
			return nil
		}
		let chat = ChatViewModel(provider: provider)
		chats.insert(chat, at: 0)
		return chat
	}

	/// Finds a chat by its stable identifier.
	/// - Parameter id: The identifier of the requested chat.
	func chat(withID id: ChatViewModel.ID) -> ChatViewModel? {
		chats.first { $0.id == id }
	}

	/// Removes a chat from the current app session.
	/// - Parameter id: The identifier of the chat to remove.
	func removeChat(withID id: ChatViewModel.ID) {
		chats.removeAll { $0.id == id }
	}
}
