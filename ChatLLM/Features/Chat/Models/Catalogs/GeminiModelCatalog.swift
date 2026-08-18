//
//  GeminiModelCatalog.swift
//  ChatLLM
//

/// Describes the Google Gemini models supported by the app.
enum GeminiModelCatalog {
	/// Stable identifier used by the ChatLLM API for Google Gemini.
	nonisolated static let providerId = "google"

	/// Google's capable, general-purpose Gemini model.
	nonisolated static let flash36Id = "gemini-3.6-flash"

	/// Google's balanced Gemini model for sustained work.
	nonisolated static let flash35Id = "gemini-3.5-flash"

	/// Google's fastest and most economical Gemini model.
	nonisolated static let flashLite35Id = "gemini-3.5-flash-lite"

	/// Model identifiers accepted by the app and ChatLLM backend.
	nonisolated static let modelIds = [flash36Id, flash35Id, flashLite35Id]

	/// Creates metadata for every supported Gemini model.
	static func models(
		isConfigured: Bool = ChatLLMConfiguration() != nil
	) -> [LanguageModel] {
		[
			model(
				id: flash36Id,
				displayName: "Gemini 3.6 Flash",
				summary: "Strong intelligence and speed for complex everyday work.",
				isConfigured: isConfigured
			),
			model(
				id: flash35Id,
				displayName: "Gemini 3.5 Flash",
				summary: "A capable balance for coding and longer conversations.",
				isConfigured: isConfigured
			),
			model(
				id: flashLite35Id,
				displayName: "Gemini 3.5 Flash-Lite",
				summary: "Fast and economical for simple, frequent requests.",
				isConfigured: isConfigured
			)
		]
	}

	/// Returns metadata for a supported Gemini model identifier.
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
