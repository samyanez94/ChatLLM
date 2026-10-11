//
//  GeminiModelCatalog.swift
//  ChatLLM
//

/// Describes current and restorable Google models.
enum GeminiModelCatalog {
	/// Stable model-author identifier used by the ChatLLM API.
	nonisolated static let providerId = "google"

	/// The stable ChatLLM identifier for Gemini 3.8 Flash.
	nonisolated static let flash38Id = "gemini-3.8-flash"

	/// The stable ChatLLM identifier for Gemini 3.5 Flash-Lite.
	nonisolated static let flashLite35Id = "gemini-3.5-flash-lite"

	/// The stable ChatLLM identifier for Gemini 3.6 Flash.
	nonisolated static let legacyFlash36Id = "gemini-3.6-flash"

	/// The stable ChatLLM identifier for Gemini 3.5 Flash.
	nonisolated static let legacyFlash35Id = "gemini-3.5-flash"

	/// Model identifiers offered for new conversations.
	nonisolated static let modelIds = [flash38Id, flashLite35Id]

	/// Older model identifiers retained for saved conversations.
	nonisolated static let legacyModelIds = [legacyFlash36Id, legacyFlash35Id]

	/// Creates picker metadata, optionally including models needed to restore chats.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil,
		includeLegacy: Bool = false
	) -> [LanguageModel] {
		let currentModels = [
			model(
				id: flash38Id,
				displayName: "Gemini 3.8 Flash",
				summary: "Strong intelligence and speed for complex everyday work.",
				isConfigured: isConfigured
			),
			model(
				id: flashLite35Id,
				displayName: "Gemini 3.5 Flash-Lite",
				summary: "Fast and economical for simple, frequent requests.",
				isConfigured: isConfigured
			)
		]
		guard includeLegacy else {
			return currentModels
		}
		return currentModels + [
			model(
				id: legacyFlash36Id,
				displayName: "Gemini 3.6 Flash",
				summary: "Strong intelligence and speed for complex everyday work.",
				isConfigured: isConfigured
			),
			model(
				id: legacyFlash35Id,
				displayName: "Gemini 3.5 Flash",
				summary: "A capable balance for coding and longer conversations.",
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
			providerName: "Google",
			summary: summary,
			availability: isConfigured
				? .available
				: .unavailable(
					message: "Add the ChatLLM backend configuration to use this model."
				)
		)
	}
}
