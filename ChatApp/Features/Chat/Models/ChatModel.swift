//
//  ChatModel.swift
//  ChatModel
//
//  Created by Samuel Yanez on 8/14/26.

/// Descriptive information about a model that can participate in a chat.
struct ChatModel {
	/// The user-facing name of the model.
	let displayName: String

	/// The model's current ability to generate a response.
	let availability: ChatModelAvailability
}
