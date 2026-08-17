//
//  ChatProviderFactory.swift
//  ChatProviderFactory
//
//  Created by Samuel Yanez on 8/14/26.

/// Creates providers for the language models supported by the app.
struct ChatProviderFactory: ChatProviderCreating {
	private let chatLLMConfiguration: ChatLLMConfiguration?

	init(chatLLMConfiguration: ChatLLMConfiguration? = ChatLLMConfiguration()) {
		self.chatLLMConfiguration = chatLLMConfiguration
	}

	/// The models supported by the app.
	var models: [LanguageModel] {
		[FoundationModelsChatService().model]
			+ OpenAIModelCatalog.models(isConfigured: chatLLMConfiguration != nil)
			+ AnthropicModelCatalog.models(isConfigured: chatLLMConfiguration != nil)
	}

	/// Creates a fresh provider session for a supported model.
	func makeProvider(for selectedModel: LanguageModel) -> (any ChatProviding)? {
		makeProvider(
			for: selectedModel,
			messages: [],
			continuationId: nil
		)
	}

	/// Restores a provider session from a persisted conversation.
	func restoreProvider(
		for model: LanguageModel,
		messages: [ChatMessage],
		continuationId: String?
	) -> (any ChatProviding)? {
		makeProvider(
			for: model,
			messages: messages,
			continuationId: continuationId
		)
	}

	private func makeProvider(
		for selectedModel: LanguageModel,
		messages: [ChatMessage],
		continuationId: String?
	) -> (any ChatProviding)? {
		let model: LanguageModel?
		switch selectedModel.providerId {
		case FoundationModelsChatService.providerId:
			guard selectedModel.id == FoundationModelsChatService.modelId else {
				return nil
			}
			return FoundationModelsChatService(messages: messages)
		case OpenAIModelCatalog.providerId:
			model = OpenAIModelCatalog.model(
				withId: selectedModel.id,
				isConfigured: chatLLMConfiguration != nil
			)
		case AnthropicModelCatalog.providerId:
			model = AnthropicModelCatalog.model(
				withId: selectedModel.id,
				isConfigured: chatLLMConfiguration != nil
			)
		default:
			return nil
		}
		guard let model else {
			return nil
		}
		return ChatLLMChatService(
			configuration: chatLLMConfiguration,
			model: model,
			messages: messages,
			continuationId: continuationId
		)
	}
}
