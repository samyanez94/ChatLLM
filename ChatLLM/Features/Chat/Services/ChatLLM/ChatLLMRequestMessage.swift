//
//  ChatLLMRequestMessage.swift
//  ChatLLM
//
//  Created by ChatLLM on 8/17/26.
//

/// A provider-neutral transcript message sent to the ChatLLM API.
nonisolated struct ChatLLMRequestMessage: Encodable, Equatable, Sendable {
	let role: Role
	let content: String

	nonisolated enum Role: String, Encodable, Sendable {
		case user
		case assistant
	}

	init(role: Role, content: String) {
		self.role = role
		self.content = content
	}

	init(_ message: ChatMessage) {
		self.role =
			switch message.role {
			case .user: .user
			case .assistant: .assistant
			}
		self.content = message.text
	}
}
