//
//  ChatModel.swift
//  ChatModel
//
//  Created by Samuel Yanez on 8/14/26.

/// Descriptive information about a model that can participate in a chat.
struct ChatModel: Identifiable {
	/// The stable identifier used to select this model.
	let id: String

	/// The user-facing name of the model.
	let displayName: String

	/// The user-facing name of the model provider.
	let providerName: String

	/// A short explanation that helps users choose this model.
	let summary: String

	/// The model's current ability to generate a response.
	let availability: ChatModelAvailability
}
