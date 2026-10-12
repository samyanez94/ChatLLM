//
//  ChatViewModel.swift
//  ChatViewModel
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import Observation
import SwiftData

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

	private(set) var streamingText = ""

	private(set) var responseID: UUID?

	private(set) var isStopping = false

	@ObservationIgnored private var responseTask: Task<Void, Never>?

	@ObservationIgnored private var interruptionStatus = ChatMessageStatus.interrupted

	@ObservationIgnored private var isDeleted = false

	private let provider: any ChatProviding

	private let modelContext: ModelContext

	/// Creates a view model for an existing persisted chat.
	init(
		chat: Chat,
		provider: any ChatProviding,
		modelContext: ModelContext
	) {
		self.chat = chat
		self.provider = provider
		self.modelContext = modelContext
	}

	/// Creates a new chat for previews, tests, and session-only callers.
	convenience init(
		id: UUID = UUID(),
		provider: any ChatProviding = FoundationModelsChatService(),
		messages: [ChatMessage] = [],
		modelContext: ModelContext
	) {
		let now = Date.now
		let chat = Chat(
			id: id,
			providerId: provider.model.providerId,
			modelId: provider.model.id,
			createdAt: now,
			updatedAt: messages.map(\.createdAt).max() ?? now,
			messages: messages
		)
		modelContext.insert(chat)
		self.init(
			chat: chat,
			provider: provider,
			modelContext: modelContext
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

		errorMessage = nil
		provider.synchronizeTranscript(messages)
		let message = trimmedDraft

		let previousUpdatedAt = chat.updatedAt
		let userMessage = chat.appendMessage(text: message, role: .user)
		do {
			try modelContext.save()
		} catch {
			chat.messages.removeAll {
				$0.id == userMessage.id
			}
			modelContext.delete(userMessage)
			chat.updatedAt = previousUpdatedAt
			errorMessage = Self.userMessageSaveError
			return
		}

		draft = ""
		isResponding = true
		responseID = UUID()
		isStopping = false
		streamingText = ""
		interruptionStatus = .interrupted
		let task = Task {
			await generateResponse(to: message)
		}
		responseTask = task
		await withTaskCancellationHandler {
			await task.value
		} onCancel: {
			task.cancel()
		}
	}

	/// Stops generation while keeping any text already received.
	func stopResponse() {
		interruptionStatus = .stopped
		isStopping = true
		responseTask?.cancel()
	}

	/// Leaving the conversation stops its request instead of generating offscreen.
	func interruptResponse() {
		responseTask?.cancel()
	}

	func cancelForDeletion() {
		isDeleted = true
		responseTask?.cancel()
	}

	private func generateResponse(to message: String) async {
		defer {
			isResponding = false
			responseTask = nil
			streamingText = ""
		}
		var status = ChatMessageStatus.completed
		do {
			try Task.checkCancellation()
			let reply = try await provider.streamReply(to: message) { text in
				guard !Task.isCancelled else {
					return
				}
				self.streamingText = text
			}
			try Task.checkCancellation()
			streamingText = reply
		} catch {
			if Task.isCancelled || error is CancellationError || (error as? URLError)?.code == .cancelled {
				status = interruptionStatus
			} else {
				status = .interrupted
				errorMessage = userFacingMessage(for: error)
			}
		}
		guard !isDeleted else {
			return
		}
		if !streamingText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
			let reply = chat.appendMessage(text: streamingText, role: .assistant)
			reply.id = responseID ?? reply.id
			reply.status = status
		}
		chat.continuationId = status == .completed ? provider.continuationId : nil
		do {
			try modelContext.save()
		} catch {
			modelContext.rollback()
			errorMessage = Self.assistantMessageSaveError
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
		case .requestFailed(_, let apiError?), .streamFailed(let apiError):
			return "\(apiError.message)\n\nRequest ID: \(apiError.requestId)"
		case .incompleteStream:
			return "The connection ended before the response finished. Any partial response has been kept."
		case .invalidHTTPResponse, .requestFailed, .invalidResponsePayload:
			return Self.genericErrorMessage
		}
	}

	private static let genericErrorMessage =
		"The response couldn’t be generated. Please try again."

	private static let userMessageSaveError =
		"Your message couldn’t be saved on this device. Please try again."

	private static let assistantMessageSaveError =
		"The response couldn’t be saved on this device. Please try again."
}
