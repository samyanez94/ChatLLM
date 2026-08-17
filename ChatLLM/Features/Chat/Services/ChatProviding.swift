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
}

extension ChatProviding {
	var continuationId: String? {
		nil
	}
}
