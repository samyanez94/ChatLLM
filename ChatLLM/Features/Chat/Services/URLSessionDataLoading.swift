//
//  URLSessionDataLoading.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/15/26.
//

import Foundation

/// Performs URL requests and allows the networking dependency to be replaced in tests.
nonisolated protocol URLSessionDataLoading: Sendable {
	func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: URLSessionDataLoading {}
