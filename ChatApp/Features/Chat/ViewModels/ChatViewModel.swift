//
//  ChatViewModel.swift
//  ChatViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation

/// Manages the conversation state and coordinates requests with the selected model provider.
@Observable
final class ChatViewModel {
	/// The message currently being composed by the user.
	var draft = ""

	/// The messages currently displayed in the conversation.
	private(set) var messages: [ChatMessage]

	/// Whether the provider is generating a reply.
	private(set) var isResponding = false

	/// The latest user-facing error, or `nil` when no error is presented.
	private(set) var errorMessage: String?

	private let provider: any ChatProviding

	init(
		provider: any ChatProviding = FoundationModelsChatService(),
		messages: [ChatMessage] = [
			ChatMessage(text: "Hi! How can I help?", role: .assistant)
		]
	) {
		self.provider = provider
		self.messages = messages
	}

	/// Information about the provider's active model.
	var model: ChatModel {
		provider.model
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
		} catch {
			errorMessage = "The response couldn’t be generated. Please try again."
		}
	}

	private var trimmedDraft: String {
		draft.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
