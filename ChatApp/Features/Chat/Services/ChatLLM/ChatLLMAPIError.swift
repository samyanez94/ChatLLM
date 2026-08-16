//
//  ChatLLMAPIError.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Error details returned by the ChatLLM API.
nonisolated struct ChatLLMAPIError: Decodable, Equatable, Sendable {
	let code: String
	let message: String
	let requestId: String

	private enum CodingKeys: String, CodingKey {
		case code
		case message
		case requestId = "request_id"
	}
}
