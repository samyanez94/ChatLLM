//
//  ChatProviderCreating.swift
//  ChatProviderCreating
//
//  Created by Samuel Yanez on 8/14/26.

/// Creates fresh provider sessions for the models supported by the app.
protocol ChatProviderCreating {
	/// The models supported by the app.
	var models: [LanguageModel] { get }

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
