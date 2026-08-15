//
//  OpenAIChatServiceError.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Conversation-level failures produced by `OpenAIChatService`.
nonisolated enum OpenAIChatServiceError: Error, Equatable, Sendable {
	case responseInProgress
}
