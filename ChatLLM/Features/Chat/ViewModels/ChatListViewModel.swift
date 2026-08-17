//
//  ChatListViewModel.swift
//  ChatListViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation
import SwiftData

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
	var models: [LanguageModel] {
		providerFactory.models
	}

	/// User-started conversations ordered by most recent activity.
	var visibleChats: [ChatViewModel] {
		chats
			.filter(\.hasUserMessages)
			.sorted { $0.updatedAt > $1.updatedAt }
	}

	/// Creates and stores a chat with a fresh provider session.
	/// - Parameter model: The model to assign to the conversation.
	/// - Returns: The created chat, or `nil` when the model cannot be used.
	func createChat(
		using model: LanguageModel,
		modelContext: ModelContext
	) -> ChatViewModel? {
		guard model.availability.isAvailable,
			let provider = providerFactory.makeProvider(for: model),
			provider.model.availability.isAvailable
		else {
			return nil
		}
		let chatViewModel = ChatViewModel(
			provider: provider,
			modelContext: modelContext
		)
		chats.append(chatViewModel)
		return chatViewModel
	}

	/// Finds a chat by its stable identifier.
	/// - Parameter id: The identifier of the requested chat.
	func chat(withId id: ChatViewModel.ID) -> ChatViewModel? {
		chats.first { $0.id == id }
	}

	/// Removes chats at offsets supplied by a list deletion action.
	/// - Parameter offsets: The positions of the chats to remove.
	func removeChats(atOffsets offsets: IndexSet) {
		let visibleChats = visibleChats
		let chatIds = offsets.map { visibleChats[$0].id }
		chats.removeAll { chatIds.contains($0.id) }
	}

	/// Removes chats that were abandoned before the user sent a message.
	func removeEmptyChats() {
		chats.removeAll { !$0.hasUserMessages }
	}
}
