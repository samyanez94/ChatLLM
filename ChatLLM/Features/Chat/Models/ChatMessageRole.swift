//
//  ChatMessageRole.swift
//  ChatMessageRole
//
//  Created by Samuel Yanez on 8/14/26.

/// The participant that authored a chat message.
nonisolated enum ChatMessageRole: Codable, Sendable {
	case user
	case assistant
}
