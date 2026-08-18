//
//  AnthropicModelCatalog.swift
//  ChatLLM
//
//  Created by ChatLLM on 8/17/26.
//

/// Describes the Anthropic models supported by the app.
enum AnthropicModelCatalog {
	/// Stable identifier used by the ChatLLM API for Anthropic.
	nonisolated static let providerId = "anthropic"

	/// The current Claude Opus alias.
	nonisolated static let opusId = "claude-opus-5"

	/// The current Claude Sonnet alias.
	nonisolated static let sonnetId = "claude-sonnet-5"

	/// The current Claude Haiku alias.
	nonisolated static let haikuId = "claude-haiku-4-5"

	/// Model identifiers accepted by the app and ChatLLM backend.
	nonisolated static let modelIds = [opusId, sonnetId, haikuId]

	/// Creates metadata for every supported Anthropic model.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> [LanguageModel] {
		[
			model(
				id: opusId,
				displayName: "Claude Opus 5",
				summary: "Powerful reasoning for complex coding and knowledge work.",
				isConfigured: isConfigured
			),
			model(
				id: sonnetId,
				displayName: "Claude Sonnet 5",
				summary: "A fast, capable balance for everyday conversations.",
				isConfigured: isConfigured
			),
			model(
				id: haikuId,
				displayName: "Claude Haiku 4.5",
				summary: "The fastest Claude option for simple and frequent tasks.",
				isConfigured: isConfigured
			)
		]
	}

	/// Returns metadata for a supported Anthropic model identifier.
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
