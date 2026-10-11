//
//  FoundationModelsChatService.swift
//  FoundationModelsChatService
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import FoundationModels

/// Generates chat responses using Apple's on-device Foundation Models framework.
final class FoundationModelsChatService: ChatProviding {

	static let providerId = "apple"

	static let modelId = "apple-foundation-model"

	private let foundationModel: SystemLanguageModel

	private var session: LanguageModelSession

	init(
		model: SystemLanguageModel = .default,
		messages: [ChatMessage] = []
	) {
		self.foundationModel = model
		if messages.isEmpty {
			self.session = LanguageModelSession(model: model)
		} else {
			self.session = LanguageModelSession(
				model: model,
				transcript: Self.makeTranscript(from: messages)
			)
		}
	}

	/// Information about the active Apple Foundation Model.
	var model: LanguageModel {
		LanguageModel(
			id: Self.modelId,
			displayName: "Apple Foundation Model",
			providerId: Self.providerId,
			providerName: "Apple",
			summary: "Private, on-device responses. Best for everyday tasks without using a server.",
			availability: availability
		)
	}

	/// Generates a reply using the current language-model session.
	func generateReply(to message: String) async throws -> String {
		try await streamReply(to: message) { _ in }
	}

	func streamReply(to message: String, onUpdate: @MainActor (String) -> Void) async throws -> String {
		var text = ""
		for try await snapshot in session.streamResponse(to: message) {
			try Task.checkCancellation()
			text = snapshot.content
			onUpdate(text)
		}
		try Task.checkCancellation()
		guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
			throw ChatLLMClientError.invalidResponsePayload
		}
		return text
	}

	func synchronizeTranscript(_ messages: [ChatMessage]) {
		session = LanguageModelSession(model: foundationModel, transcript: Self.makeTranscript(from: messages))
	}

	static func makeTranscript(from messages: [ChatMessage]) -> Transcript {
		let entries = messages.sorted { $0.sequence < $1.sequence }
			.map { message in
				let segment = Transcript.Segment.text(
					Transcript.TextSegment(content: message.text)
				)
				switch message.role {
				case .user:
					return Transcript.Entry.prompt(
						Transcript.Prompt(segments: [segment])
					)
				case .assistant:
					return Transcript.Entry.response(
						Transcript.Response(assetIDs: [], segments: [segment])
					)
				}
			}
		return Transcript(entries: entries)
	}

	private var availability: LanguageModelAvailability {
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
