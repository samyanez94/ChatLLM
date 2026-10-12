//
//  MessageBubble.swift
//  MessageBubble
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftStreamingMarkdown
import SwiftUI

struct MessageBubble: View {

	private static let markdownConfig = MarkdownRenderConfig.default
		.withCodeBlockConfig(value: .init(theme: .xcode))

	let text: String

	let role: ChatMessageRole

	var status: ChatMessageStatus = .completed

	var streamSource: StreamingMarkdownSource?

	init(
		text: String,
		role: ChatMessageRole,
		status: ChatMessageStatus = .completed,
		streamSource: StreamingMarkdownSource? = nil
	) {
		self.text = text
		self.role = role
		self.status = status
		self.streamSource = streamSource
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
		} else if let streamSource {
			StreamedMarkdownView(
				source: streamSource,
				config: Self.markdownConfig.withShouldAnimateText(value: true)
			)
			// The library retains its source in a StateObject. A new source needs a new renderer.
			.id(ObjectIdentifier(streamSource))
		} else {
			MarkdownView(
				text: text,
				config: Self.markdownConfig.withShouldAnimateText(value: false)
			)
		}
	}
}
