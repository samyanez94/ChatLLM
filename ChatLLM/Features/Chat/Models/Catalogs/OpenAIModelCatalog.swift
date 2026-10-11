//
//  OpenAIModelCatalog.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Describes current and restorable OpenAI models.
enum OpenAIModelCatalog {
	/// Stable model-author identifier used by the ChatLLM API.
	nonisolated static let providerId = "openai"

	/// The stable ChatLLM identifier for GPT-6 Luna.
	nonisolated static let lunaId = "gpt-6-luna"

	/// The stable ChatLLM identifier for GPT-6.1 Sol.
	nonisolated static let solId = "gpt-6.1-sol"

	/// The stable ChatLLM identifier for GPT-6 Astra.
	nonisolated static let astraId = "gpt-6-astra"

	/// The stable ChatLLM identifier for GPT-5.6 Luna.
	nonisolated static let legacyLunaId = "gpt-5.6-luna"

	/// The stable ChatLLM identifier for GPT-5.6 Terra.
	nonisolated static let legacyTerraId = "gpt-5.6-terra"

	/// The stable ChatLLM identifier for GPT-5.6 Sol.
	nonisolated static let legacySolId = "gpt-5.6-sol"

	/// Model identifiers offered for new conversations.
	nonisolated static let modelIds = [lunaId, solId, astraId]

	/// Older model identifiers retained for saved conversations.
	nonisolated static let legacyModelIds = [legacyLunaId, legacyTerraId, legacySolId]

	/// Creates picker metadata, optionally including models needed to restore chats.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil,
		includeLegacy: Bool = false
	) -> [LanguageModel] {
		let currentModels = [
			model(
				id: lunaId,
				displayName: "GPT-6 Luna",
				summary: "Fast and economical. Best for simple questions and frequent use.",
				isConfigured: isConfigured
			),
			model(
				id: solId,
				displayName: "GPT-6.1 Sol",
				summary: "A strong balance of capability and cost for coding and everyday work.",
				isConfigured: isConfigured
			),
			model(
				id: astraId,
				displayName: "GPT-6 Astra",
				summary: "The most capable option. Best for the hardest reasoning and coding tasks.",
				isConfigured: isConfigured
			)
		]
		guard includeLegacy else {
			return currentModels
		}
		return currentModels + [
			model(
				id: legacyLunaId,
				displayName: "GPT-5.6 Luna",
				summary: "Fast and economical. Best for simple questions and frequent use.",
				isConfigured: isConfigured
			),
			model(
				id: legacyTerraId,
				displayName: "GPT-5.6 Terra",
				summary: "A strong balance of capability and cost. Best for most conversations.",
				isConfigured: isConfigured
			),
			model(
				id: legacySolId,
				displayName: "GPT-5.6 Sol",
				summary: "Highly capable. Best for complex problems and coding.",
				isConfigured: isConfigured
			)
		]
	}

	/// Looks up both current and legacy models without changing their identity.
	static func model(
		withId modelId: LanguageModel.ID,
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> LanguageModel? {
		models(isConfigured: isConfigured, includeLegacy: true).first { $0.id == modelId }
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
			availability: isConfigured
				? .available
				: .unavailable(
					message: "Add the ChatLLM backend configuration to use this model."
				)
		)
	}
}
