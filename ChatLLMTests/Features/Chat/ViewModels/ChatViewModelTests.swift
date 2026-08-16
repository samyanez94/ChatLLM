//
//  ChatViewModelTests.swift
//  ChatLLMTests
//

import Testing

@testable import ChatLLM

// MARK: - ChatViewModelTests

@MainActor
struct ChatViewModelTests {
	@Test("Sending a message appends the user message and reply")
	func sendsMessage() async throws {
		let provider = StubChatProvider(result: .success("Hello back"))
		let viewModel = ChatViewModel(provider: provider, messages: [])
		viewModel.draft = "  Hello  "

		await viewModel.sendMessage()

		#expect(provider.receivedMessages == ["Hello"])
		#expect(viewModel.messages.map(\.text) == ["Hello", "Hello back"])
		#expect(viewModel.draft.isEmpty)
		#expect(viewModel.isResponding == false)
		#expect(viewModel.errorMessage == nil)
	}

	@Test("A failed response keeps the user message and presents an error")
	func handlesFailedResponse() async {
		let provider = StubChatProvider(result: .failure(TestError.responseFailed))
		let viewModel = ChatViewModel(provider: provider, messages: [])
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(viewModel.messages.map(\.text) == ["Hello"])
		#expect(
			viewModel.errorMessage
				== "The response couldn’t be generated. Please try again."
		)
		#expect(viewModel.isResponding == false)
	}

	@Test("A backend error preserves its message and request identifier")
	func preservesBackendError() async {
		let apiError = ChatLLMAPIError(
			code: "rate_limited",
			message: "The provider rate limit has been exceeded.",
			requestId: "request-123"
		)
		let provider = StubChatProvider(
			result: .failure(
				ChatLLMClientError.requestFailed(statusCode: 429, apiError: apiError)
			)
		)
		let viewModel = ChatViewModel(provider: provider, messages: [])
		viewModel.draft = "Hello"

		await viewModel.sendMessage()

		#expect(
			viewModel.errorMessage
				== "The provider rate limit has been exceeded.\n\nRequest ID: request-123"
		)
	}
}

// MARK: - StubChatProvider

@MainActor
private final class StubChatProvider: ChatProviding {
	let model = ChatModel(
		id: "test-model",
		displayName: "Test Model",
		providerId: "test-provider",
		providerName: "Test Provider",
		summary: "A model used in tests.",
		availability: .available
	)

	private let result: Result<String, any Error>

	private(set) var receivedMessages: [String] = []

	init(result: Result<String, any Error>) {
		self.result = result
	}

	func generateReply(to message: String) async throws -> String {
		receivedMessages.append(message)
		return try result.get()
	}
}

// MARK: - TestError

private enum TestError: Error {
	case responseFailed
}
