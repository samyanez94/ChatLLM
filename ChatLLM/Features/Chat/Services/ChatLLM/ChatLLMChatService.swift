//
//  ChatLLMChatService.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Maintains one OpenAI conversation through the hosted ChatLLM backend.
final class ChatLLMChatService: ChatProviding {
	private let client: any ChatLLMResponseCreating
	private(set) var continuationId: String?
	private var isGenerating = false

	/// Information about the OpenAI model used by this conversation.
	let model: LanguageModel

	/// Creates a live ChatLLM conversation when backend configuration is available.
	init?(
		configuration: ChatLLMConfiguration? = ChatLLMConfiguration(),
		model: LanguageModel,
		continuationId: String? = nil
	) {
		guard let configuration else {
			return nil
		}
		self.client = ChatLLMClient(configuration: configuration)
		self.model = model
		self.continuationId = continuationId
	}

	/// Creates a ChatLLM conversation with an injected response client.
	init(
		client: any ChatLLMResponseCreating,
		model: LanguageModel,
		continuationId: String? = nil
	) {
		self.client = client
		self.model = model
		self.continuationId = continuationId
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
