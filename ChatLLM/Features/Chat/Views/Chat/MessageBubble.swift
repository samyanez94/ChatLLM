//
//  MessageBubble.swift
//  MessageBubble
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI
import UIKit

struct MessageBubble: View {
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
				.accessibilityLabel("\(speakerName): \(message.text)")
				.contextMenu {
					Button("Copy", systemImage: "doc.on.doc", action: copyMessage)
				}
			if message.role == .assistant {
				Spacer(minLength: 48)
			}
		}
	}

	@ViewBuilder
	private var messageText: some View {
		if message.role == .assistant {
			Text(markdownText)
				.font(.body)
				.lineSpacing(3)
				.textSelection(.enabled)
		} else {
			Text(message.text)
				.font(.body)
		}
	}

	private var markdownText: AttributedString {
		(try? AttributedString(markdown: message.text)) ?? AttributedString(message.text)
	}

	private var backgroundStyle: Color {
		message.role == .user ? .accentColor : .secondary.opacity(0.15)
	}

	private var foregroundStyle: Color {
		message.role == .user ? .white : .primary
	}

	private var speakerName: String {
		message.role == .user ? "You" : "Assistant"
	}

	private func copyMessage() {
		UIPasteboard.general.string = message.text
	}
}
