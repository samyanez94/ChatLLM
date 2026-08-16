//
//  ChatLLMConfigurationTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 8/16/26.
//

import Foundation
import Testing

@testable import ChatLLM

struct ChatLLMConfigurationTests {
	@Test("Valid hosted configuration is accepted")
	func acceptsValidConfiguration() throws {
		let configuration = try #require(
			ChatLLMConfiguration(
				endpoint: "https://example.supabase.co/functions/v1/chat",
				publishableKey: "sb_publishable_example"
			)
		)

		#expect(
			configuration.endpoint
				== URL(string: "https://example.supabase.co/functions/v1/chat")
		)
		#expect(configuration.publishableKey == "sb_publishable_example")
	}

	@Test("Configuration values are trimmed")
	func trimsConfigurationValues() throws {
		let configuration = try #require(
			ChatLLMConfiguration(
				endpoint: "  https://example.supabase.co/functions/v1/chat  ",
				publishableKey: "  sb_publishable_example  "
			)
		)

		#expect(
			configuration.endpoint.absoluteString
				== "https://example.supabase.co/functions/v1/chat"
		)
		#expect(configuration.publishableKey == "sb_publishable_example")
	}

	@Test(
		"Invalid endpoints are rejected",
		arguments: [
			nil,
			"",
			"http://example.supabase.co/functions/v1/chat",
			"not-a-url"
		] as [String?]
	)
	func rejectsInvalidEndpoint(endpoint: String?) {
		let configuration = ChatLLMConfiguration(
			endpoint: endpoint,
			publishableKey: "sb_publishable_example"
		)

		#expect(configuration == nil)
	}

	@Test(
		"Invalid publishable keys are rejected",
		arguments: [
			nil,
			"",
			"sb_publishable_",
			"sb_secret_example",
			"example-key"
		] as [String?]
	)
	func rejectsInvalidPublishableKey(publishableKey: String?) {
		let configuration = ChatLLMConfiguration(
			endpoint: "https://example.supabase.co/functions/v1/chat",
			publishableKey: publishableKey
		)

		#expect(configuration == nil)
	}
}
