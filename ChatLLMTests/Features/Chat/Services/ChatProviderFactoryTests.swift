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

		let openAIModels = factory.models.filter {
			$0.providerId == OpenAIModelCatalog.providerId
		}

		#expect(openAIModels.map(\.id) == OpenAIModelCatalog.modelIds)
		#expect(openAIModels.allSatisfy { $0.providerName == "OpenAI" })
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

		let openAIModels = factory.models.filter {
			$0.providerId == OpenAIModelCatalog.providerId
		}

		#expect(openAIModels.count == OpenAIModelCatalog.modelIds.count)
		#expect(openAIModels.allSatisfy { $0.availability.isAvailable == false })
		#expect(
			openAIModels.allSatisfy {
				$0.availability.unavailableMessage
					== "Add the ChatLLM backend configuration to use this model."
			}
		)
	}

	@Test("The model catalog includes the current Claude family")
	func includesAnthropicModels() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let models = factory.models.filter {
			$0.providerId == AnthropicModelCatalog.providerId
		}

		#expect(models.map(\.id) == AnthropicModelCatalog.modelIds)
		#expect(models.allSatisfy { $0.providerName == "Anthropic" })
		#expect(
			models.map(\.displayName)
				== ["Claude Opus 5", "Claude Sonnet 5", "Claude Haiku 4.5"]
		)
		#expect(models.allSatisfy { $0.availability.isAvailable })
	}

	@Test("The factory includes and creates a Gemini provider")
	func createsGeminiProvider() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let models = factory.models.filter {
			$0.providerId == GeminiModelCatalog.providerId
		}

		#expect(models.map(\.id) == GeminiModelCatalog.modelIds)
		#expect(models.allSatisfy { $0.providerName == "Google" })
		let model = try #require(
			models.first { $0.id == GeminiModelCatalog.flash36Id }
		)
		let provider = try #require(factory.makeProvider(for: model))
		#expect(provider is ChatLLMChatService)
		#expect(provider.model.id == GeminiModelCatalog.flash36Id)
	}

	@Test(
		"The factory creates each Anthropic provider when configured",
		arguments: AnthropicModelCatalog.modelIds
	)
	func createsAnthropicProvider(modelId: LanguageModel.ID) throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let model = try #require(factory.models.first { $0.id == modelId })

		let provider = try #require(factory.makeProvider(for: model))

		#expect(provider is ChatLLMChatService)
		#expect(provider.model.id == modelId)
	}

	@Test("Anthropic models remain listed but unavailable without configuration")
	func anthropicUnavailableWithoutConfiguration() {
		let factory = ChatProviderFactory(chatLLMConfiguration: nil)
		let models = factory.models.filter {
			$0.providerId == AnthropicModelCatalog.providerId
		}

		#expect(models.map(\.id) == AnthropicModelCatalog.modelIds)
		#expect(models.allSatisfy { $0.availability.isAvailable == false })
	}

	@Test(
		"The factory creates each OpenAI provider when configured",
		arguments: OpenAIModelCatalog.modelIds
	)
	func createsOpenAIProvider(modelId: LanguageModel.ID) throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let model = try #require(factory.models.first { $0.id == modelId })

		let provider = try #require(factory.makeProvider(for: model))

		#expect(provider is ChatLLMChatService)
		#expect(provider.model.id == modelId)
	}

	@Test(
		"The factory rejects each OpenAI provider without configuration",
		arguments: OpenAIModelCatalog.modelIds
	)
	func rejectsOpenAIProviderWithoutConfiguration(modelId: LanguageModel.ID) {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: nil
		)
		guard let model = factory.models.first(where: { $0.id == modelId }) else {
			Issue.record("Expected model '\(modelId)' in the catalog.")
			return
		}

		let provider = factory.makeProvider(for: model)

		#expect(provider == nil)
	}

	@Test("Each Luna provider starts a fresh conversation")
	func createsFreshLunaProviders() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let model = try #require(
			factory.models.first { $0.id == OpenAIModelCatalog.lunaId }
		)

		let first = try #require(
			factory.makeProvider(for: model) as? ChatLLMChatService
		)
		let second = try #require(
			factory.makeProvider(for: model) as? ChatLLMChatService
		)

		#expect(first !== second)
	}

	@Test("The factory restores an OpenAI continuation identifier")
	func restoresOpenAIContinuation() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let model = try #require(
			factory.models.first { $0.id == OpenAIModelCatalog.lunaId }
		)

		let provider = try #require(
			factory.restoreProvider(
				for: model,
				messages: [],
				continuationId: "response-1"
			) as? ChatLLMChatService
		)

		#expect(provider.continuationId == "response-1")
	}

	@Test("Unknown model identifiers remain unsupported")
	func rejectsUnknownModel() throws {
		let factory = ChatProviderFactory(
			chatLLMConfiguration: try makeConfiguration()
		)
		let model = LanguageModel(
			id: "unknown-model",
			displayName: "Unknown",
			providerId: OpenAIModelCatalog.providerId,
			providerName: "OpenAI",
			summary: "An unsupported model.",
			availability: .available
		)

		#expect(factory.makeProvider(for: model) == nil)
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
