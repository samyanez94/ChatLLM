//
//  OpenAIResponse.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// The text result and identifier returned by the OpenAI Responses API.
nonisolated struct OpenAIResponse: Equatable, Sendable {
	let id: String
	let outputText: String
}
