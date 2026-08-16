//
//  ChatProviderFactoryTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 8/15/26.
//

import Testing

@testable import ChatLLM

@MainActor
struct ChatProviderFactoryTests {
	@Test("The model catalog includes the GPT-5.6 family")
	func includesOpenAIModels() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)

		let openAIModels = factory.models.filter { $0.providerName == "OpenAI" }

		#expect(openAIModels.map(\.id) == OpenAIModelCatalog.modelIds)
		#expect(
			openAIModels.map(\.displayName)
				== ["GPT-5.6 Luna", "GPT-5.6 Terra", "GPT-5.6 Sol"]
		)
		#expect(openAIModels.allSatisfy { $0.availability.isAvailable })
	}

	@Test("OpenAI models remain listed but unavailable without configuration")
	func unavailableWithoutConfiguration() {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: nil
		)

		let openAIModels = factory.models.filter { $0.providerName == "OpenAI" }

		#expect(openAIModels.count == OpenAIModelCatalog.modelIds.count)
		#expect(openAIModels.allSatisfy { $0.availability.isAvailable == false })
		#expect(
			openAIModels.allSatisfy {
				$0.availability.unavailableMessage
					== "Add the ChatLLM backend configuration to use this model."
			}
		)
	}

	@Test(
		"The factory creates each OpenAI provider when configured",
		arguments: OpenAIModelCatalog.modelIds
	)
	func createsOpenAIProvider(modelId: ChatModel.ID) throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)

		let provider = try #require(factory.makeProvider(for: modelId))

		#expect(provider is ChatLLMChatService)
		#expect(provider.model.id == modelId)
	}

	@Test(
		"The factory rejects each OpenAI provider without configuration",
		arguments: OpenAIModelCatalog.modelIds
	)
	func rejectsOpenAIProviderWithoutConfiguration(modelId: ChatModel.ID) {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: nil
		)

		let provider = factory.makeProvider(for: modelId)

		#expect(provider == nil)
	}

	@Test("Each Luna provider starts a fresh conversation")
	func createsFreshLunaProviders() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)

		let first = try #require(
			factory.makeProvider(for: OpenAIModelCatalog.lunaId) as? ChatLLMChatService
		)
		let second = try #require(
			factory.makeProvider(for: OpenAIModelCatalog.lunaId) as? ChatLLMChatService
		)

		#expect(first !== second)
	}

	@Test("Unknown model identifiers remain unsupported")
	func rejectsUnknownModel() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)

		#expect(factory.makeProvider(for: "unknown-model") == nil)
	}

	private func makeConfiguration() throws -> ChatLLMConfiguration {
		try #require(
			ChatLLMConfiguration(
				endpoint: "https://example.supabase.co/functions/v1/chat",
				publishableKey: "sb_publishable_test"
			)
		)
	}
}
