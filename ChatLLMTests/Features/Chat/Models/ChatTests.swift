//
//  ChatTests.swift
//  ChatLLMTests
//

import Foundation
import SwiftData
import Testing

@testable import ChatLLM

@MainActor
struct ChatTests {
	@Test("Appending the first message establishes its transcript position")
	func appendsFirstMessage() {
		let createdAt = Date(timeIntervalSince1970: 100)
		let chat = Chat(
			providerId: "test-provider",
			modelId: "test-model",
			updatedAt: .distantPast
		)

		let message = chat.appendMessage(
			text: "Hello",
			role: .user,
			createdAt: createdAt
		)

		#expect(message.sequence == 0)
		#expect(message.chat === chat)
		#expect(chat.messages.map(\.id) == [message.id])
		#expect(chat.updatedAt == createdAt)
	}

	@Test("Appending uses the greatest existing sequence")
	func appendsAfterGreatestSequence() {
		let chat = Chat(
			providerId: "test-provider",
			modelId: "test-model",
			messages: [
				ChatMessage(sequence: 4, text: "Later", role: .assistant),
				ChatMessage(sequence: 1, text: "Earlier", role: .user)
			]
		)

		let message = chat.appendMessage(text: "Newest", role: .user)

		#expect(message.sequence == 5)
	}

	@Test("Deleting a chat cascade-deletes its messages")
	func cascadeDeletesMessages() throws {
		let container = try makeChatModelContainer()
		let context = container.mainContext
		let chat = Chat(
			providerId: "test-provider",
			modelId: "test-model"
		)
		chat.appendMessage(text: "Hello", role: .user)
		chat.appendMessage(text: "Hello back", role: .assistant)
		context.insert(chat)
		try context.save()

		context.delete(chat)
		try context.save()

		#expect(try context.fetchCount(FetchDescriptor<Chat>()) == 0)
		#expect(try context.fetchCount(FetchDescriptor<ChatMessage>()) == 0)
	}
}

@MainActor
private func makeChatModelContainer() throws -> ModelContainer {
	try ModelContainer(
		for: Schema(versionedSchema: ChatSchemaV1.self),
		migrationPlan: ChatMigrationPlan.self,
		configurations: ModelConfiguration(isStoredInMemoryOnly: true)
	)
}
