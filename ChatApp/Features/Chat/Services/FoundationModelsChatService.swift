//
//  FoundationModelsChatService.swift
//  FoundationModelsChatService
//
//  Created by Samuel Yanez on 8/14/26.

import FoundationModels

/// Generates chat responses using Apple's on-device Foundation Models framework.
final class FoundationModelsChatService: ChatProviding {
	static let modelID = "apple-foundation-model"

	private let foundationModel: SystemLanguageModel

	private let session: LanguageModelSession

	init(model: SystemLanguageModel = .default) {
		self.foundationModel = model
		self.session = LanguageModelSession(model: model)
	}

	/// Information about the active Apple Foundation Model.
	var model: ChatModel {
		ChatModel(
			id: Self.modelID,
			displayName: "Apple Foundation Model",
			providerName: "Apple",
			availability: availability
		)
	}

	/// Generates a reply using the current language-model session.
	func generateReply(to message: String) async throws -> String {
		try await session.respond(to: message).content
	}

	private var availability: ChatModelAvailability {
		switch foundationModel.availability {
		case .available:
			.available
		case .unavailable(.deviceNotEligible):
			.unavailable(message: "This device doesn’t support Apple Intelligence.")
		case .unavailable(.appleIntelligenceNotEnabled):
			.unavailable(message: "Turn on Apple Intelligence in Settings to use this model.")
		case .unavailable(.modelNotReady):
			.unavailable(message: "Apple Foundation Model is still downloading. Try again shortly.")
		case .unavailable:
			.unavailable(message: "Apple Foundation Model is currently unavailable.")
		}
	}
}
