//
//  OpenAIConfiguration.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

import Foundation

/// Reads the local OpenAI configuration embedded in the app at build time.
struct OpenAIConfiguration {
	private static let secretsResourceName = "OpenAISecrets"
	private static let apiKey = "APIKey"

	/// The configured API key, or `nil` when the build has no usable key.
	let apiKey: String?

	/// Creates a configuration from an explicitly supplied API key.
	/// - Parameter apiKey: The API key to validate.
	init(apiKey: String?) {
		self.apiKey = Self.validatedAPIKey(from: apiKey)
	}

	init(bundle: Bundle = .main) {
		guard let url = bundle.url(forResource: Self.secretsResourceName, withExtension: "plist"),
			let secrets = NSDictionary(contentsOf: url)
		else {
			self.init(apiKey: nil)
			return
		}

		self.init(apiKey: secrets[Self.apiKey] as? String)
	}

	private static func validatedAPIKey(from value: String?) -> String? {
		guard let value else {
			return nil
		}
		let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard !trimmedValue.isEmpty,
			trimmedValue != "your-openai-api-key"
		else {
			return nil
		}

		return trimmedValue
	}
}
