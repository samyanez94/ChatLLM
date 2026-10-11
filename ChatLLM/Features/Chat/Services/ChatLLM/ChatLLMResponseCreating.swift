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

	func streamResponse(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String?,
		onUpdate: @Sendable (String) async -> Void
	) async throws -> ChatLLMResponse
}

extension ChatLLMResponseCreating {

	func streamResponse(
		provider: String,
		model: String,
		messages: [ChatLLMRequestMessage],
		continuationId: String?,
		onUpdate: @Sendable (String) async -> Void
	) async throws -> ChatLLMResponse {
		let response = try await createResponse(
			provider: provider,
			model: model,
			messages: messages,
			continuationId: continuationId
		)
		try Task.checkCancellation()
		await onUpdate(response.outputText)
		return response
	}
}
