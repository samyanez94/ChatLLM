//
//  ChatLLMChatService.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Maintains one OpenAI conversation through the hosted ChatLLM backend.
final class ChatLLMChatService: ChatProviding {
	private let client: any ChatLLMResponseCreating
	private var continuationId: String?
	private var isGenerating = false

	/// Information about the OpenAI model used by this conversation.
	let model: ChatModel

	/// Creates a live ChatLLM conversation when backend configuration is available.
	init?(
		configuration: ChatLLMConfiguration? = ChatLLMConfiguration(),
		model: ChatModel
	) {
		guard let configuration else {
			return nil
		}
		self.client = ChatLLMClient(configuration: configuration)
		self.model = model
	}

	/// Creates a ChatLLM conversation with an injected response client.
	init(
		client: any ChatLLMResponseCreating,
		model: ChatModel
	) {
		self.client = client
		self.model = model
	}

	/// Generates a reply and continues from the last successful backend response.
	func generateReply(to message: String) async throws -> String {
		guard isGenerating == false else {
			throw ChatLLMChatServiceError.responseInProgress
		}
		isGenerating = true
		defer {
			isGenerating = false
		}

		let response = try await client.createResponse(
			provider: model.providerId,
			model: model.id,
			input: message,
			continuationId: continuationId
		)
		continuationId = response.continuationId
		return response.outputText
	}
}
