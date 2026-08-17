//
//  ChatListViewModel.swift
//  ChatListViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation
import SwiftData

/// Loads and manages the chats retained on this device.
@Observable
final class ChatListViewModel {
	/// The chats currently available to the app.
	private(set) var chats: [ChatViewModel]

	/// The latest user-facing persistence error, or `nil` when none is presented.
	private(set) var errorMessage: String?

	private let modelContext: ModelContext

	private let providerFactory: any ChatProviderCreating

	init(
		modelContext: ModelContext,
		providerFactory: any ChatProviderCreating = ChatProviderFactory()
	) {
		self.modelContext = modelContext
		self.providerFactory = providerFactory
		self.chats = []
		loadChats()
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

	/// Whether a persistence error is currently presented.
	var isShowingError: Bool {
		get {
			errorMessage != nil
		}
		set {
			if !newValue {
				errorMessage = nil
			}
		}
	}

	/// Creates and stores a chat with a fresh provider session.
	/// - Parameter model: The model to assign to the conversation.
	/// - Returns: The created chat, or `nil` when the model cannot be used.
	func createChat(using model: LanguageModel) -> ChatViewModel? {
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

	private func loadChats() {
		var descriptor = FetchDescriptor<Chat>(
			sortBy: [SortDescriptor(\.updatedAt, order: .reverse)]
		)
		descriptor.relationshipKeyPathsForPrefetching = [\.messages]
		do {
			chats = try modelContext.fetch(descriptor).compactMap(makeViewModel)
		} catch {
			errorMessage = "Your saved chats couldn’t be loaded. Please restart the app and try again."
		}
	}

	private func makeViewModel(for chat: Chat) -> ChatViewModel? {
		guard
			let model = providerFactory.models.first(where: {
				$0.providerId == chat.providerId && $0.id == chat.modelId
			}),
			let provider = providerFactory.restoreProvider(
				for: model,
				messages: chat.messages,
				continuationId: chat.continuationId
			)
		else {
			return nil
		}
		return ChatViewModel(
			chat: chat,
			provider: provider,
			modelContext: modelContext
		)
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

		let chatsToRemove = offsets.map { visibleChats[$0] }

		for chatViewModel in chatsToRemove {
			modelContext.delete(chatViewModel.chat)
		}

		do {
			try modelContext.save()
			let chatIds = Set(chatsToRemove.map(\.id))
			chats.removeAll { chatIds.contains($0.id) }
		} catch {
			modelContext.rollback()
			errorMessage = "The selected chats couldn’t be deleted. Please try again."
		}
	}

	/// Removes chats that were abandoned before the user sent a message.
	func removeEmptyChats() {
		chats.removeAll { !$0.hasUserMessages }
	}
}
