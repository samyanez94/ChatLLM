//
//  FoundationModelsChatService.swift
//  FoundationModelsChatService
//
//  Created by Samuel Yanez on 8/14/26.

import FoundationModels

final class FoundationModelsChatService: ChatProviding {
    
	let displayName = "Apple Foundation Model"

	private let session: LanguageModelSession

	init(session: LanguageModelSession = LanguageModelSession()) {
		self.session = session
	}

	func generateReply(to message: String) async throws -> String {
		try await session.respond(to: message).content
	}
}
