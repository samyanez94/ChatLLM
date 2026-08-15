//
//  ChatProviderFactoryTests.swift
//  ChatAppTests
//
//  Created by Samuel Yanez on 8/15/26.
//

import Testing

@testable import ChatApp

@MainActor
struct ChatProviderFactoryTests {
	@Test("The model catalog includes GPT-5.6 Luna")
	func includesLuna() throws {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: "test-api-key")
		)

		let luna = try #require(
			factory.models.first { $0.id == OpenAIModelCatalog.lunaId }
		)
		#expect(luna.displayName == "GPT-5.6 Luna")
		#expect(luna.providerName == "OpenAI")
		#expect(luna.availability.isAvailable)
	}

	@Test("Luna remains listed but unavailable without credentials")
	func unavailableWithoutCredentials() throws {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: nil)
		)

		let luna = try #require(
			factory.models.first { $0.id == OpenAIModelCatalog.lunaId }
		)
		#expect(luna.availability.isAvailable == false)
		#expect(luna.availability.unavailableMessage == "Add an OpenAI API key to use this model.")
	}

	@Test("The factory creates an OpenAI provider when credentials are available")
	func createsLunaProvider() throws {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: "test-api-key")
		)

		let provider = try #require(factory.makeProvider(for: OpenAIModelCatalog.lunaId))

		#expect(provider is OpenAIChatService)
		#expect(provider.model.id == OpenAIModelCatalog.lunaId)
	}

	@Test("The factory does not create a Luna provider without credentials")
	func rejectsLunaWithoutCredentials() {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: nil)
		)

		let provider = factory.makeProvider(for: OpenAIModelCatalog.lunaId)

		#expect(provider == nil)
	}

	@Test("Each Luna provider starts a fresh conversation")
	func createsFreshLunaProviders() throws {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: "test-api-key")
		)

		let first = try #require(
			factory.makeProvider(for: OpenAIModelCatalog.lunaId) as? OpenAIChatService
		)
		let second = try #require(
			factory.makeProvider(for: OpenAIModelCatalog.lunaId) as? OpenAIChatService
		)

		#expect(first !== second)
	}

	@Test("Unknown model identifiers remain unsupported")
	func rejectsUnknownModel() {
		let factory = ChatProviderFactory(
			openAIConfiguration: OpenAIConfiguration(apiKey: "test-api-key")
		)

		#expect(factory.makeProvider(for: "unknown-model") == nil)
	}
}
