//
//  FoundationModelsChatService.swift
//  FoundationModelsChatService
//
//  Created by Samuel Yanez on 8/14/26.

import FoundationModels

final class FoundationModelsChatService: ChatProviding {
	let displayName = "Apple Foundation Model"

	private let model: SystemLanguageModel
    
	private let session: LanguageModelSession

	init(model: SystemLanguageModel = .default) {
		self.model = model
		self.session = LanguageModelSession(model: model)
	}

	var availability: ChatModelAvailability {
		switch model.availability {
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

	func generateReply(to message: String) async throws -> String {
		try await session.respond(to: message).content
	}
}
