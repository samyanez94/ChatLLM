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
	var models: [ChatModel] {
		[
			FoundationModelsChatService().model,
			OpenAIModelCatalog.luna(isConfigured: chatLLMConfiguration != nil)
		]
	}

	/// Creates a fresh provider session for a supported model.
	func makeProvider(for modelID: ChatModel.ID) -> (any ChatProviding)? {
		switch modelID {
		case FoundationModelsChatService.modelID:
			FoundationModelsChatService()
		case OpenAIModelCatalog.lunaId:
			ChatLLMChatService(configuration: chatLLMConfiguration)
		default:
			nil
		}
	}
}
