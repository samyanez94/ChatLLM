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

	/// Creates GPT-5.6 Luna metadata for the current backend configuration.
	static func luna(isConfigured: Bool = ChatLLMConfiguration() != nil) -> ChatModel {
		ChatModel(
			id: lunaId,
			displayName: "GPT-5.6 Luna",
			providerName: "OpenAI",
			availability: availability(isConfigured: isConfigured)
		)
	}

	private static func availability(
		isConfigured: Bool
	) -> ChatModelAvailability {
		guard isConfigured else {
			return .unavailable(
				message: "Add the ChatLLM backend configuration to use this model."
			)
		}
		return .available
	}
}
