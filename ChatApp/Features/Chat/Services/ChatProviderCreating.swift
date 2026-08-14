//
//  ChatProviderCreating.swift
//  ChatProviderCreating
//
//  Created by Samuel Yanez on 8/14/26.

/// Creates fresh provider sessions for the models supported by the app.
protocol ChatProviderCreating {
	/// The models supported by the app.
	var models: [ChatModel] { get }

	/// Creates a fresh provider session for a model.
	/// - Parameter modelID: The stable identifier of the requested model.
	/// - Returns: A provider for the model, or `nil` when the identifier is unsupported.
	func makeProvider(for modelID: ChatModel.ID) -> (any ChatProviding)?
}
