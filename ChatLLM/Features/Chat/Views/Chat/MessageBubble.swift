//
//  MessageBubble.swift
//  MessageBubble
//
//  Created by Samuel Yanez on 8/14/26.

import MarkdownUI
import SwiftUI

struct MessageBubble: View {
	private static let assistantTheme = Theme.gitHub.text {
		BackgroundColor(.clear)
	}

	let text: String

	let role: ChatMessageRole

	var status: ChatMessageStatus = .completed

	init(message: ChatMessage) {
		text = message.text
		role = message.role
		status = message.status
	}

	init(text: String, role: ChatMessageRole) {
		self.text = text
		self.role = role
	}

	private var isUser: Bool {
		role == .user
	}

	var body: some View {
		HStack {
			if isUser {
				Spacer(minLength: 48)
			}
			VStack(alignment: .leading, spacing: 6) {
				messageText
				if status != .completed {
					Text(status == .stopped ? "Stopped" : "Interrupted")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
			}
			.padding(.horizontal, 14)
			.padding(.vertical, 10)
			.background(isUser ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(.fill.tertiary), in: .rect(cornerRadius: 18))
			.foregroundStyle(isUser ? Color.white : .primary)
			if !isUser {
				Spacer(minLength: 48)
			}
		}
	}

	@ViewBuilder
	private var messageText: some View {
		if isUser {
			Text(text)
				.font(.body)
		} else {
			Markdown(text)
				.markdownTheme(Self.assistantTheme)
		}
	}
}
