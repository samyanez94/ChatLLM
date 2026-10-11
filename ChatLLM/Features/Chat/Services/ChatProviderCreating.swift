//
//  ChatProviderCreating.swift
//  ChatProviderCreating
//
//  Created by Samuel Yanez on 8/14/26.

/// Creates fresh provider sessions for the models supported by the app.
protocol ChatProviderCreating {
	/// The models offered for new conversations.
	var models: [LanguageModel] { get }

	/// All supported models, including older models needed to restore saved chats.
	var supportedModels: [LanguageModel] { get }

	/// Creates a fresh provider session for a model.
	/// - Parameter model: The requested model and its stable provider identity.
	/// - Returns: A provider for the model, or `nil` when the identifier is unsupported.
	func makeProvider(for model: LanguageModel) -> (any ChatProviding)?

	/// Restores a provider session from a persisted conversation.
	func restoreProvider(
		for model: LanguageModel,
		messages: [ChatMessage],
		continuationId: String?
	) -> (any ChatProviding)?
}

extension ChatProviderCreating {
	var supportedModels: [LanguageModel] {
		models
	}
}
