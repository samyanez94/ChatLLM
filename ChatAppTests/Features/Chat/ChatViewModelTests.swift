//
//  ChatViewModelTests.swift
//  ChatViewModelTests
//
//  Created by Samuel Yanez on 8/14/26.

import Testing
@testable import ChatApp

@MainActor
struct ChatViewModelTests {
    @Test
    func sendMessageTrimsDraftAndAppendsReply() async throws {
        let viewModel = ChatViewModel(
            provider: ChatProviderStub(reply: "Hello!"),
            messages: []
        )
        viewModel.draft = "  Hi there  \n"

        await viewModel.sendMessage()

        #expect(viewModel.draft.isEmpty)
        try #require(viewModel.messages.count == 2)

        let userMessage = try #require(viewModel.messages.first)
        #expect(userMessage.text == "Hi there")
        #expect(userMessage.role == .user)

        let assistantMessage = try #require(viewModel.messages.last)
        #expect(assistantMessage.text == "Hello!")
        #expect(assistantMessage.role == .assistant)
        #expect(!viewModel.isResponding)
        #expect(!viewModel.isShowingError)
    }

    @Test
    func emptyDraftDoesNotSend() async {
        let viewModel = ChatViewModel(
            provider: ChatProviderStub(reply: "Unused"),
            messages: []
        )
        viewModel.draft = " \n "

        await viewModel.sendMessage()

        #expect(viewModel.messages.isEmpty)
        #expect(!viewModel.canSend)
    }

    @Test
    func providerFailurePresentsAlertAndKeepsUserMessage() async throws {
        let viewModel = ChatViewModel(
            provider: ChatProviderStub(reply: nil),
            messages: []
        )
        viewModel.draft = "Hello"

        await viewModel.sendMessage()

        try #require(viewModel.messages.count == 1)

        let message = try #require(viewModel.messages.first)
        #expect(message.text == "Hello")
        #expect(message.role == .user)
        #expect(viewModel.isShowingError)
        #expect(!viewModel.errorMessage.isEmpty)
        #expect(!viewModel.isResponding)
    }
}
