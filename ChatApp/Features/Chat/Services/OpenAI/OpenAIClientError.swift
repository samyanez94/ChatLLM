//
//  OpenAIClientError.swift
//  ChatApp
//
//  Created by Samuel Yanez on 8/15/26.
//

/// Failures produced while communicating with the OpenAI API.
nonisolated enum OpenAIClientError: Error, Equatable, Sendable {
	case invalidHTTPResponse
	case httpError(statusCode: Int, apiError: OpenAIAPIError?)
	case invalidResponsePayload
	case missingOutputText
}
