//
//  FoundationModelsChatServiceTests.swift
//  ChatLLMTests
//

import FoundationModels
import Testing

@testable import ChatLLM

@MainActor
struct FoundationModelsChatServiceTests {
	@Test("Persisted messages become a Foundation Models transcript")
	func restoresTranscript() throws {
		let transcript = FoundationModelsChatService.makeTranscript(
			from: [
				ChatMessage(sequence: 1, text: "Hello back", role: .assistant),
				ChatMessage(sequence: 0, text: "Hello", role: .user)
			]
		)

		#expect(transcript.count == 2)

		guard case .prompt(let prompt) = transcript[0],
			case .text(let userText) = prompt.segments.first
		else {
			Issue.record("Expected the first entry to be the user prompt.")
			return
		}
		#expect(userText.content == "Hello")

		guard case .response(let response) = transcript[1],
			case .text(let assistantText) = response.segments.first
		else {
			Issue.record("Expected the second entry to be the assistant response.")
			return
		}
		#expect(assistantText.content == "Hello back")
	}
}
