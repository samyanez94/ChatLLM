//
//  ChatProvidingTests.swift
//  ChatLLMTests
//

import Testing

@testable import ChatLLM

@MainActor
struct ChatProvidingTests {
	@Test("Providers default to having no continuation identifier")
	func continuationIdentifierDefaultsToNil() {
		let provider = ProviderWithoutContinuation()

		#expect(provider.continuationId == nil)
	}
}

@MainActor
private struct ProviderWithoutContinuation: ChatProviding {
	let model = LanguageModel(
		id: "test-model",
		displayName: "Test Model",
		providerId: "test-provider",
		providerName: "Test Provider",
		summary: "A model used in tests.",
		availability: .available
	)

	func generateReply(to message: String) async throws -> String {
		"Unused"
	}
}
