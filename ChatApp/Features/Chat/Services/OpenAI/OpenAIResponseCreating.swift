//
//  OpenAIResponseCreating.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Creates text responses with an OpenAI model.
nonisolated protocol OpenAIResponseCreating: Sendable {
	func createResponse(
		model: String,
		input: String,
		previousResponseId: String?
	) async throws -> OpenAIResponse
}

extension OpenAIClient: OpenAIResponseCreating {}
