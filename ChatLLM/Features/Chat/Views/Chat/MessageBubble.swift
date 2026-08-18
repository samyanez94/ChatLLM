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

	let message: ChatMessage

	private var isUser: Bool {
		message.role == .user
	}

	var body: some View {
		HStack {
			if isUser {
				Spacer(minLength: 48)
			}
			messageText
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
			Text(message.text)
				.font(.body)
		} else {
			Markdown(message.text)
				.markdownTheme(Self.assistantTheme)
		}
	}
}
