//
//  ChatLLMResponseCreating.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Creates provider-neutral responses through the ChatLLM backend.
nonisolated protocol ChatLLMResponseCreating: Sendable {
	func createResponse(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String?
	) async throws -> ChatLLMResponse
}
