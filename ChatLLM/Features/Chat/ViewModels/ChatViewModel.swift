//
//  ChatViewModel.swift
//  ChatViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation

/// Represents one chat and coordinates its conversation with a fixed model provider.
@Observable
final class ChatViewModel: Identifiable {
	/// The persisted chat coordinated by this view model.
	let chat: Chat

	/// The message currently being composed by the user.
	var draft = ""

	/// Whether the provider is generating a reply.
	private(set) var isResponding = false

	/// The latest user-facing error, or `nil` when no error is presented.
	private(set) var errorMessage: String?

	private let provider: any ChatProviding

	/// Creates a view model for an existing persisted chat.
	init(chat: Chat, provider: any ChatProviding) {
		self.chat = chat
		self.provider = provider
	}

	/// Creates a new chat for previews, tests, and session-only callers.
	convenience init(
		id: UUID = UUID(),
		provider: any ChatProviding = FoundationModelsChatService(),
		messages: [ChatMessage] = []
	) {
		let now = Date.now
		self.init(
			chat: Chat(
				id: id,
				providerId: provider.model.providerId,
				modelId: provider.model.id,
				createdAt: now,
				updatedAt: messages.map(\.createdAt).max() ?? now,
				messages: messages
			),
			provider: provider
		)
	}

	/// The stable identifier for this conversation.
	var id: Chat.ID {
		chat.id
	}

	/// The messages currently displayed in transcript order.
	var messages: [ChatMessage] {
		chat.messages.sorted { $0.sequence < $1.sequence }
	}

	/// The date of the conversation's most recent message.
	var updatedAt: Date {
		chat.updatedAt
	}

	/// Information about the model assigned to this conversation.
	var model: LanguageModel {
		provider.model
	}

	/// A user-facing title derived from the first user message.
	var title: String {
		messages.first(where: { $0.role == .user })?.text ?? "New Chat"
	}

	/// The most recent message text for use in a conversation summary.
	var preview: String {
		messages.last?.text ?? "No messages yet"
	}

	/// Whether the conversation contains at least one user message.
	var hasUserMessages: Bool {
		messages.contains { $0.role == .user }
	}

	/// Whether the current draft can be sent to the active model.
	var canSend: Bool {
		model.availability.isAvailable && !isResponding && !trimmedDraft.isEmpty
	}

	/// Whether the error alert is currently presented.
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

	/// Sends the current draft and appends the generated reply to the conversation.
	func sendMessage() async {
		guard canSend else {
			return
		}

		let message = trimmedDraft

		chat.appendMessage(text: message, role: .user)
		draft = ""
		isResponding = true
		defer {
			isResponding = false
		}

		do {
			let reply = try await provider.generateReply(to: message)
			chat.appendMessage(text: reply, role: .assistant)
		} catch is CancellationError {
			return
		} catch {
			errorMessage = userFacingMessage(for: error)
		}
	}

	private var trimmedDraft: String {
		draft.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	private func userFacingMessage(for error: any Error) -> String {
		guard let clientError = error as? ChatLLMClientError else {
			return Self.genericErrorMessage
		}
		switch clientError {
		case .invalidAPIKey:
			return "ChatLLM couldn’t authenticate with the backend. Check the app configuration."
		case .requestFailed(_, let apiError?):
			return "\(apiError.message)\n\nRequest ID: \(apiError.requestId)"
		case .invalidHTTPResponse, .requestFailed, .invalidResponsePayload:
			return Self.genericErrorMessage
		}
	}

	private static let genericErrorMessage =
		"The response couldn’t be generated. Please try again."
}
