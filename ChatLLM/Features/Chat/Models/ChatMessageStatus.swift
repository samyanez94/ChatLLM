//
//  ChatMessageStatus.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 10/11/26.
//

/// A final response outcome. Active generation stays in memory until it ends.
enum ChatMessageStatus: String, Codable {
	case completed
	case stopped
	case interrupted
}
