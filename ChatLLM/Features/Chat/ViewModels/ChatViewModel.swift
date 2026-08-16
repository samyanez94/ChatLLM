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
	/// The stable identifier for this conversation.
	let id: UUID

	/// The message currently being composed by the user.
	var draft = ""

	/// The messages currently displayed in the conversation.
	private(set) var messages: [ChatMessage]

	/// The date of the conversation's most recent message.
	private(set) var updatedAt: Date

	/// Whether the provider is generating a reply.
	private(set) var isResponding = false

	/// The latest user-facing error, or `nil` when no error is presented.
	private(set) var errorMessage: String?

	private let provider: any ChatProviding

	init(
		id: UUID = UUID(),
		provider: any ChatProviding = FoundationModelsChatService(),
		messages: [ChatMessage] = [
			ChatMessage(text: "Hi! How can I help?", role: .assistant)
		]
	) {
		self.id = id
		self.provider = provider
		self.messages = messages
		self.updatedAt = .now
	}

	/// Information about the model assigned to this conversation.
	var model: ChatModel {
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

		messages.append(ChatMessage(text: message, role: .user))
		updatedAt = .now
		draft = ""
		isResponding = true
		defer {
			isResponding = false
		}

		do {
			let reply = try await provider.generateReply(to: message)
			messages.append(
				ChatMessage(text: reply, role: .assistant)
			)
			updatedAt = .now
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
