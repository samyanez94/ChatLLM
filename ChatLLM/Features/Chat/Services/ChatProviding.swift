//
//  ChatProviding.swift
//  ChatProviding
//
//  Created by Samuel Yanez on 8/14/26.

/// A provider capable of generating chat responses with a language model.
protocol ChatProviding {
	/// Information about the provider's active model.
	var model: LanguageModel { get }

	/// Opaque provider state used to resume the conversation, when required.
	var continuationId: String? { get }

	/// Generates a reply to a user message.
	/// - Parameter message: The user's message.
	/// - Returns: The model's generated reply.
	func generateReply(to message: String) async throws -> String

	/// Reports full text snapshots; return normally only after a verified completion.
	func streamReply(to message: String, onUpdate: @MainActor (String) -> Void) async throws -> String

	/// Starts the next request from the saved transcript, including partial replies.
	func synchronizeTranscript(_ messages: [ChatMessage])
}

extension ChatProviding {
	func streamReply(to message: String, onUpdate: @MainActor (String) -> Void) async throws -> String {
		let reply = try await generateReply(to: message)
		try Task.checkCancellation()
		onUpdate(reply)
		return reply
	}

	func synchronizeTranscript(_ messages: [ChatMessage]) {}

	var continuationId: String? {
		nil
	}
}
