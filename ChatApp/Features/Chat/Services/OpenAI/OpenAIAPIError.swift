//
//  OpenAIAPIError.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Error details returned in an OpenAI API error response.
nonisolated struct OpenAIAPIError: Decodable, Equatable, Sendable {
	let message: String
	let type: String?
	let parameter: String?
	let code: String?

	private enum CodingKeys: String, CodingKey {
		case message
		case type
		case parameter = "param"
		case code
	}
}
