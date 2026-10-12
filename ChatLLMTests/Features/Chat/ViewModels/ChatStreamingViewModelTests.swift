//
//  ChatStreamingViewModelTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 10/11/26.
//

@testable import ChatLLM
import Foundation
import SwiftData
import Testing

@MainActor
struct ChatStreamingViewModelTests {
	@Test("Text appears before completion and is persisted only at the end")
	func incrementalResponse() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		var liveID: UUID?
		provider.onSnapshot = {
			liveID = viewModel.responseID
			#expect(liveID != nil)
			#expect(viewModel.streamingText == "First")
			#expect(viewModel.isResponding)
			#expect(!viewModel.canSend)
			#expect(viewModel.messages.map(\.text) == ["Question"])
		}
		await viewModel.sendMessage()
		#expect(viewModel.messages.map(\.text) == ["Question", "First and last"])
		#expect(viewModel.messages.last?.status == .completed)
		#expect(viewModel.messages.last?.id == liveID)
		#expect(viewModel.streamingText.isEmpty)
		#expect(!viewModel.isResponding)
		let context = ModelContext(container)
		#expect(try context.fetchCount(FetchDescriptor<ChatMessage>()) == 2)
	}

	@Test("Stop keeps the latest partial snapshot and marks it stopped")
	func stop() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		provider.onSnapshot = {
			viewModel.stopResponse()
			#expect(viewModel.isStopping)
		}
		await viewModel.sendMessage()
		#expect(viewModel.messages.last?.text == "First")
		#expect(viewModel.messages.last?.status == .stopped)
		#expect(viewModel.errorMessage == nil)
		let context = ModelContext(container)
		let messages = try context.fetch(FetchDescriptor<ChatMessage>(sortBy: [SortDescriptor(\.sequence)]))
		#expect(messages.last?.status == .stopped)
		#expect(messages.last?.text == "First")
		// The next request and a restored chat both see the saved partial response.
		provider.onSnapshot = nil
		viewModel.draft = "Continue"
		await viewModel.sendMessage()
		#expect(provider.historiesAtGeneration.last == ["Question", "First"])
		#expect(viewModel.messages.count == 4)
	}

	@Test("A stream failure saves its newest partial text and permits a follow-up")
	func failure() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		defer {
			withExtendedLifetime(container) {}
		}
		provider.failure = ChatLLMClientError.incompleteStream
		await viewModel.sendMessage()
		#expect(viewModel.messages.last?.text == "First and last")
		#expect(viewModel.messages.last?.status == .interrupted)
		#expect(viewModel.errorMessage != nil)
		#expect(!viewModel.isResponding)
		provider.failure = nil
		viewModel.draft = "Continue"
		await viewModel.sendMessage()
		#expect(provider.historiesAtGeneration.last == ["Question", "First and last"])
		#expect(viewModel.errorMessage == nil)
	}

	@Test("Leaving the conversation marks a partial response interrupted")
	func leaveChat() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		defer {
			withExtendedLifetime(container) {}
		}
		provider.onSnapshot = { viewModel.interruptResponse() }
		await viewModel.sendMessage()
		#expect(viewModel.messages.last?.status == .interrupted)
		#expect(viewModel.errorMessage == nil)
	}

	@Test("Cancelling before text does not create an empty assistant message")
	func stopBeforeText() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		defer {
			withExtendedLifetime(container) {}
		}
		provider.beforeSnapshot = { viewModel.stopResponse() }
		await viewModel.sendMessage()
		#expect(viewModel.messages.map(\.text) == ["Question"])
		#expect(viewModel.errorMessage == nil)
		#expect(!viewModel.isResponding)
	}

	@Test("A deleted chat cannot receive a late assistant message")
	func deletion() async throws {
		let (container, provider, viewModel) = try makeViewModel()
		provider.onSnapshot = {
			viewModel.cancelForDeletion()
			container.mainContext.delete(viewModel.chat)
			try? container.mainContext.save()
		}
		await viewModel.sendMessage()
		#expect(try container.mainContext.fetchCount(FetchDescriptor<Chat>()) == 0)
		#expect(try container.mainContext.fetchCount(FetchDescriptor<ChatMessage>()) == 0)
	}

	private func makeViewModel() throws -> (ModelContainer, StreamingProvider, ChatViewModel) {
		let container = try ModelContainer(
			for: Schema(versionedSchema: ChatSchemaV1.self),
			configurations: ModelConfiguration(isStoredInMemoryOnly: true)
		)
		let provider = StreamingProvider()
		let viewModel = ChatViewModel(
			provider: provider,
			modelContext: container.mainContext
		)
		viewModel.draft = "Question"
		return (container, provider, viewModel)
	}
}

@MainActor
private final class StreamingProvider: ChatProviding {

	let model = LanguageModel(
		id: "test",
		displayName: "Test",
		providerId: "test",
		providerName: "Test",
		summary: "Test",
		availability: .available
	)

	var onSnapshot: (() -> Void)?

	var beforeSnapshot: (() -> Void)?

	var failure: (any Error)?

	var transcript = [String]()

	var historiesAtGeneration = [[String]]()

	func generateReply(to message: String) async throws -> String {
		Issue.record("Must use streaming")
		return ""
	}

	func streamReply(
		to message: String,
		onUpdate: @MainActor (String) -> Void
	) async throws -> String {
		historiesAtGeneration.append(transcript)
		beforeSnapshot?()
		try Task.checkCancellation()
		onUpdate("First")
		onSnapshot?()
		try Task.checkCancellation()
		onUpdate("First and last")
		if let failure {
			throw failure
		}
		return "First and last"
	}
	func synchronizeTranscript(_ messages: [ChatMessage]) {
		transcript = messages.sorted { $0.sequence < $1.sequence }.map(\.text)
	}
}
