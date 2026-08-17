//
//  ChatLLMChatService.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Maintains one hosted conversation through the ChatLLM backend.
final class ChatLLMChatService: ChatProviding {

	private let client: any ChatLLMResponseCreating

	private(set) var continuationId: String?

	private var isGenerating = false

	private var messages: [ChatLLMRequestMessage]

	/// Information about the hosted model used by this conversation.
	let model: LanguageModel

	/// Creates a live ChatLLM conversation when backend configuration is available.
	init?(
		configuration: ChatLLMConfiguration? = ChatLLMConfiguration(),
		model: LanguageModel,
		messages: [ChatMessage] = [],
		continuationId: String? = nil
	) {
		guard let configuration else {
			return nil
		}
		self.client = ChatLLMClient(configuration: configuration)
		self.model = model
		self.messages = messages.sorted { $0.sequence < $1.sequence }.map(ChatLLMRequestMessage.init)
		self.continuationId = continuationId
	}

	/// Creates a ChatLLM conversation with an injected response client.
	init(
		client: any ChatLLMResponseCreating,
		model: LanguageModel,
		messages: [ChatLLMRequestMessage] = [],
		continuationId: String? = nil
	) {
		self.client = client
		self.model = model
		self.messages = messages
		self.continuationId = continuationId
	}

	/// Restores a hosted conversation with an injected response client.
	init(
		client: any ChatLLMResponseCreating,
		model: LanguageModel,
		persistedMessages: [ChatMessage],
		continuationId: String? = nil
	) {
		self.client = client
		self.model = model
		self.messages = persistedMessages.sorted { $0.sequence < $1.sequence }.map(ChatLLMRequestMessage.init)
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
		let userMessage = ChatLLMRequestMessage(role: .user, content: message)
		let requestMessages = messages + [userMessage]
		let response = try await client.createResponse(
			provider: model.providerId,
			model: model.id,
			messages: requestMessages,
			continuationId: continuationId
		)
		messages =
			requestMessages + [
				ChatLLMRequestMessage(role: .assistant, content: response.outputText)
			]
		continuationId = response.continuationId
		return response.outputText
	}
}
