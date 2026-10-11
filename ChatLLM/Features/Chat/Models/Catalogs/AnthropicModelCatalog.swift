//
//  AnthropicModelCatalog.swift
//  ChatLLM
//
//  Created by ChatLLM on 8/17/26.
//

/// Describes current and restorable Anthropic models.
enum AnthropicModelCatalog {
	/// Stable model-author identifier used by the ChatLLM API.
	nonisolated static let providerId = "anthropic"

	/// The stable ChatLLM identifier for Claude Opus 5.5.
	nonisolated static let opusId = "claude-opus-5-5"

	/// The stable ChatLLM identifier for Claude Sonnet 5.5.
	nonisolated static let sonnetId = "claude-sonnet-5-5"

	/// The stable ChatLLM identifier for Claude Haiku 5.5.
	nonisolated static let haikuId = "claude-haiku-5-5"

	/// The stable ChatLLM identifier for Claude Opus 5.
	nonisolated static let legacyOpusId = "claude-opus-5"

	/// The stable ChatLLM identifier for Claude Sonnet 5.
	nonisolated static let legacySonnetId = "claude-sonnet-5"

	/// The stable ChatLLM identifier for Claude Haiku 4.5.
	nonisolated static let legacyHaikuId = "claude-haiku-4-5"

	/// Model identifiers offered for new conversations.
	nonisolated static let modelIds = [opusId, sonnetId, haikuId]

	/// Older model identifiers retained for saved conversations.
	nonisolated static let legacyModelIds = [legacyOpusId, legacySonnetId, legacyHaikuId]

	/// Creates picker metadata, optionally including models needed to restore chats.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil,
		includeLegacy: Bool = false
	) -> [LanguageModel] {
		let currentModels = [
			model(
				id: opusId,
				displayName: "Claude Opus 5.5",
				summary: "Powerful reasoning for complex coding and knowledge work.",
				isConfigured: isConfigured
			),
			model(
				id: sonnetId,
				displayName: "Claude Sonnet 5.5",
				summary: "A fast, capable balance for everyday conversations.",
				isConfigured: isConfigured
			),
			model(
				id: haikuId,
				displayName: "Claude Haiku 5.5",
				summary: "Fast and economical for simple and frequent tasks.",
				isConfigured: isConfigured
			)
		]
		guard includeLegacy else {
			return currentModels
		}
		return currentModels + [
			model(
				id: legacyOpusId,
				displayName: "Claude Opus 5",
				summary: "Powerful reasoning for complex coding and knowledge work.",
				isConfigured: isConfigured
			),
			model(
				id: legacySonnetId,
				displayName: "Claude Sonnet 5",
				summary: "A fast, capable balance for everyday conversations.",
				isConfigured: isConfigured
			),
			model(
				id: legacyHaikuId,
				displayName: "Claude Haiku 4.5",
				summary: "Fast responses for simple and frequent tasks.",
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
			providerName: "Anthropic",
			summary: summary,
			availability: isConfigured
				? .available
				: .unavailable(
					message: "Add the ChatLLM backend configuration to use this model."
				)
		)
	}
}
