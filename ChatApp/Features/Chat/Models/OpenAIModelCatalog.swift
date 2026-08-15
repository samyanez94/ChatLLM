//
//  OpenAIModelCatalog.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Describes the OpenAI models supported by the app.
enum OpenAIModelCatalog {
	/// The stable OpenAI API identifier for GPT-5.6 Luna.
	static let lunaId = "gpt-5.6-luna"

	/// Creates the GPT-5.6 Luna model metadata for the current configuration.
	/// - Parameter configuration: The local OpenAI credential configuration.
	static func luna(
		configuration: OpenAIConfiguration = OpenAIConfiguration()
	) -> ChatModel {
		ChatModel(
			id: lunaId,
			displayName: "GPT-5.6 Luna",
			providerName: "OpenAI",
			availability: availability(for: configuration)
		)
	}

	private static func availability(
		for configuration: OpenAIConfiguration
	) -> ChatModelAvailability {
		guard configuration.apiKey != nil else {
			return .unavailable(
				message: "Add an OpenAI API key to use this model."
			)
		}
		return .available
	}
}
