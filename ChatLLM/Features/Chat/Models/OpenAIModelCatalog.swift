//
//  OpenAIModelCatalog.swift
//  ChatLLM
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
	) -> [LanguageModel] {
		[
			model(
				id: lunaId,
				displayName: "GPT-5.6 Luna",
				summary: "Fast and economical. Best for simple questions and frequent use.",
				isConfigured: isConfigured
			),
			model(
				id: terraId,
				displayName: "GPT-5.6 Terra",
				summary: "A strong balance of capability and cost. Best for most conversations.",
				isConfigured: isConfigured
			),
			model(
				id: solId,
				displayName: "GPT-5.6 Sol",
				summary: "The most capable option. Best for complex problems and coding.",
				isConfigured: isConfigured
			)
		]
	}

	/// Returns metadata for a supported OpenAI model identifier.
	static func model(
		withId modelId: LanguageModel.ID,
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> LanguageModel? {
		models(isConfigured: isConfigured).first { $0.id == modelId }
	}

	private static func model(
		id: LanguageModel.ID,
		displayName: String,
		summary: String,
		isConfigured: Bool
	) -> LanguageModel {
		LanguageModel(
			id: id,
			displayName: displayName,
			providerId: providerId,
			providerName: "OpenAI",
			summary: summary,
			availability: availability(isConfigured: isConfigured)
		)
	}

	private static func availability(
		isConfigured: Bool
	) -> LanguageModelAvailability {
		guard isConfigured else {
			return .unavailable(
				message: "Add the ChatLLM backend configuration to use this model."
			)
		}
		return .available
	}
}
