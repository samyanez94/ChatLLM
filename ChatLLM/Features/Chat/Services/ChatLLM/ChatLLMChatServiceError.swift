//
//  ChatLLMChatServiceError.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Conversation-level failures produced by `ChatLLMChatService`.
nonisolated enum ChatLLMChatServiceError: Error, Equatable, Sendable {
	case responseInProgress
}
