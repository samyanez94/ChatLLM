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
		if selectedModel.providerId == FoundationModelsChatService.providerId,
			selectedModel.id == FoundationModelsChatService.modelId
		{
			return FoundationModelsChatService(messages: messages)
		}
		guard selectedModel.providerId == OpenAIModelCatalog.providerId,
			let model = OpenAIModelCatalog.model(
				withId: selectedModel.id,
				isConfigured: chatLLMConfiguration != nil
			)
		else {
			return nil
		}
		return ChatLLMChatService(
			configuration: chatLLMConfiguration,
			model: model,
			continuationId: continuationId
		)
	}
}
