//
//  ChatLLMClientError.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.
//

/// Failures produced while communicating with the ChatLLM API.
nonisolated enum ChatLLMClientError: Error, Equatable, Sendable {
	case invalidHTTPResponse
	case invalidAPIKey
	case requestFailed(statusCode: Int, apiError: ChatLLMAPIError?)
	case invalidResponsePayload
}
