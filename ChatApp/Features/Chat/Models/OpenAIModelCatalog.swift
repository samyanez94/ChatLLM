//
//  OpenAIModelCatalog.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Describes the OpenAI models supported by the app.
enum OpenAIModelCatalog {
	/// Stable identifier used by the ChatLLM API for OpenAI.
	nonisolated static let providerId = "openai"

	/// The stable OpenAI API identifier for GPT-5.6 Luna.
	nonisolated static let lunaId = "gpt-5.6-luna"

	/// The stable OpenAI API identifier for GPT-5.6 Terra.
	nonisolated static let terraId = "gpt-5.6-terra"

	/// The stable OpenAI API identifier for GPT-5.6 Sol.
	nonisolated static let solId = "gpt-5.6-sol"

	/// Model identifiers accepted by the app and ChatLLM backend.
	nonisolated static let modelIds = [lunaId, terraId, solId]

	/// Creates metadata for every supported OpenAI model.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> [ChatModel] {
		[
			model(id: lunaId, displayName: "GPT-5.6 Luna", isConfigured: isConfigured),
			model(id: terraId, displayName: "GPT-5.6 Terra", isConfigured: isConfigured),
			model(id: solId, displayName: "GPT-5.6 Sol", isConfigured: isConfigured)
		]
	}

	/// Returns metadata for a supported OpenAI model identifier.
	static func model(
		withId modelId: ChatModel.ID,
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> ChatModel? {
		models(isConfigured: isConfigured).first { $0.id == modelId }
	}

	private static func model(
		id: ChatModel.ID,
		displayName: String,
		isConfigured: Bool
	) -> ChatModel {
		ChatModel(
			id: id,
			displayName: displayName,
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
