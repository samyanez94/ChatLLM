//
//  ChatProviderStub.swift
//  ChatProviderStub
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation

@testable import ChatApp

struct ChatProviderStub: ChatProviding {
	let reply: String?

	func generateReply(to _: String) async throws -> String {
		guard let reply else {
			throw CocoaError(.fileReadUnknown)
		}
		return reply
	}
}
