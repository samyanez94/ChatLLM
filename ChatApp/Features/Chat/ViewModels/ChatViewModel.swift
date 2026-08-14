//
//  ChatViewModel.swift
//  ChatViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation

@Observable
final class ChatViewModel {
	var draft = ""
	private(set) var messages: [ChatMessage]
	private(set) var isResponding = false
	private(set) var errorMessage = ""
	var isShowingError = false

	@ObservationIgnored
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

	var canSend: Bool {
		!isResponding && !trimmedDraft.isEmpty
	}

	var modelDisplayName: String {
		provider.displayName
	}

	func sendMessage() async {
		let message = trimmedDraft
		guard !trimmedDraft.isEmpty,
			!isResponding
		else {
			return
		}

		messages.append(ChatMessage(text: message, role: .user))
		draft = ""
		isResponding = true
		defer {
			isResponding = false
		}

		do {
			let reply = try await provider.generateReply(to: message)
			try Task.checkCancellation()
			messages.append(
				ChatMessage(text: reply, role: .assistant)
			)
		} catch is CancellationError {
			return
		} catch {
			errorMessage = "The response couldn’t be generated. Please try again."
			isShowingError = true
		}
	}

	private var trimmedDraft: String {
		draft.trimmingCharacters(in: .whitespacesAndNewlines)
	}
}
