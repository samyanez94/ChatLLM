//
//  ChatMessage.swift
//  ChatMessage
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation

struct ChatMessage: Identifiable {
	let id = UUID()
	let text: String
	let role: ChatMessageRole
}
