//
//  ChatLLMResponse.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// A successful response returned by the ChatLLM API.
nonisolated struct ChatLLMResponse: Equatable, Sendable {
	let provider: String
	let model: String
	let continuationId: String
	let outputText: String
	let requestId: String?
}
