//
//  Chat.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.

import Foundation
import SwiftData

/// A chat retained on this device.
@Model
final class Chat {
	/// The stable identifier for this chat.
	@Attribute(.unique) var id: UUID

	/// The stable identifier of the provider used by this chat.
	var providerId: String

	/// The stable identifier of the model used by this chat.
	var modelId: String

	/// The date when the chat was created.
	var createdAt: Date

	/// The date of the chat's most recent activity.
	var updatedAt: Date

	/// The messages belonging to this chat.
	@Relationship(deleteRule: .cascade, inverse: \ChatMessage.chat)
	var messages: [ChatMessage]

	init(
		id: UUID = UUID(),
		providerId: String,
		modelId: String,
		createdAt: Date = .now,
		updatedAt: Date = .now,
		messages: [ChatMessage] = []
	) {
		self.id = id
		self.providerId = providerId
		self.modelId = modelId
		self.createdAt = createdAt
		self.updatedAt = updatedAt
		self.messages = messages
	}
}
