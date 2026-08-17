//
//  ChatLLMConfiguration.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

import Foundation

/// Validated, non-secret configuration for the hosted ChatLLM API.
nonisolated struct ChatLLMConfiguration: Equatable, Sendable {

	private static let resourceName = "ChatLLMConfiguration"

	/// Hosted ChatLLM API endpoint.
	let endpoint: URL

	/// Supabase publishable project key sent with client requests.
	let publishableKey: String

	/// Creates a configuration from explicit values.
	init?(endpoint: URL?, publishableKey: String?) {
		guard let endpoint,
			endpoint.scheme == "https",
			endpoint.host() != nil,
			let publishableKey = Self.validatedPublishableKey(publishableKey)
		else {
			return nil
		}
		self.endpoint = endpoint
		self.publishableKey = publishableKey
	}

	/// Creates a configuration from an endpoint string and publishable key.
	init?(endpoint: String?, publishableKey: String?) {
		guard let endpoint else {
			return nil
		}
		self.init(
			endpoint: URL(string: endpoint.trimmingCharacters(in: .whitespacesAndNewlines)),
			publishableKey: publishableKey
		)
	}

	/// Reads the ChatLLM configuration embedded in the application bundle.
	init?(bundle: Bundle = .main) {
		guard
			let url = bundle.url(
				forResource: Self.resourceName,
				withExtension: "plist"
			),
			let data = try? Data(contentsOf: url),
			let payload = try? PropertyListDecoder().decode(Payload.self, from: data)
		else {
			return nil
		}
		self.init(
			endpoint: payload.endpoint,
			publishableKey: payload.publishableKey
		)
	}

	private static func validatedPublishableKey(_ value: String?) -> String? {
		guard let value else {
			return nil
		}
		let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
		guard trimmedValue.hasPrefix("sb_publishable_"),
			trimmedValue.count > "sb_publishable_".count
		else {
			return nil
		}
		return trimmedValue
	}
}

extension ChatLLMConfiguration {
	private nonisolated struct Payload: Decodable {
		let endpoint: String
		let publishableKey: String

		private enum CodingKeys: String, CodingKey {
			case endpoint = "Endpoint"
			case publishableKey = "PublishableKey"
		}
	}
}
