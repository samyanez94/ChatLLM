//
//  OpenAIModelCatalogTests.swift
//  ChatAppTests
//
//  Created by Samuel Yanez on 8/15/26.
//

import Testing

@testable import ChatApp

struct OpenAIModelCatalogTests {
	@Test @MainActor func lunaHasExpectedMetadataWhenConfigured() {
		let model = OpenAIModelCatalog.luna(
			configuration: OpenAIConfiguration(apiKey: "test-api-key")
		)

		#expect(model.id == "gpt-5.6-luna")
		#expect(model.displayName == "GPT-5.6 Luna")
		#expect(model.providerName == "OpenAI")
		#expect(model.availability == .available)
	}

	@Test @MainActor func lunaIsUnavailableWithoutCredentials() {
		let model = OpenAIModelCatalog.luna(
			configuration: OpenAIConfiguration(apiKey: nil)
		)

		#expect(
			model.availability
				== .unavailable(
					message: "Add an OpenAI API key to use this model."
				)
		)
	}
}
