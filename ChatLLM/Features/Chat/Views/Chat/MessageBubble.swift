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

	var body: some View {
		HStack {
			if message.role == .user {
				Spacer(minLength: 48)
			}
			messageText
				.padding(.horizontal, 14)
				.padding(.vertical, 10)
				.background(backgroundStyle)
				.foregroundStyle(foregroundStyle)
				.clipShape(.rect(cornerRadius: 18))
			if message.role == .assistant {
				Spacer(minLength: 48)
			}
		}
	}

	@ViewBuilder
	private var messageText: some View {
		if message.role == .assistant {
			Markdown(message.text)
				.markdownTheme(
					Theme.gitHub.text {
						BackgroundColor(.clear)
					}
				)
		} else {
			Text(message.text)
				.font(.body)
		}
	}

	private var backgroundStyle: Color {
		message.role == .user ? .accentColor : .secondary.opacity(0.15)
	}

	private var foregroundStyle: Color {
		message.role == .user ? .white : .primary
	}
}
