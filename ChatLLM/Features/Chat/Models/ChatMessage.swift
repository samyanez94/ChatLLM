//
//  ChatMessage.swift
//  ChatMessage
//
//  Created by Samuel Yanez on 8/14/26.

import Foundation
import SwiftData

/// A persisted message belonging to a chat.
@Model
final class ChatMessage {
	/// The stable identifier for this message.
	@Attribute(.unique) var id: UUID

	/// The message's position in its chat transcript.
	var sequence: Int

	/// The message content displayed to the user.
	var text: String

	/// Whether generation completed, was stopped, or was interrupted.
	var status: ChatMessageStatus

	/// The participant that authored the message.
	var role: ChatMessageRole

	/// The date when the message was created.
	var createdAt: Date

	/// The chat containing this message.
	var chat: Chat?

	init(
		id: UUID = UUID(),
		sequence: Int,
		text: String,
		role: ChatMessageRole,
		createdAt: Date = .now,
		status: ChatMessageStatus = .completed,
		chat: Chat? = nil
	) {
		self.id = id
		self.sequence = sequence
		self.text = text
		self.status = status
		self.role = role
		self.createdAt = createdAt
		self.chat = chat
	}
}
