//
//  ChatListRow.swift
//  ChatListRow
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatListRow: View {
	let chat: ChatViewModel

	var body: some View {
		VStack(alignment: .leading, spacing: 4) {
			HStack(alignment: .firstTextBaseline) {
				Text(chat.title)
					.font(.headline)
					.lineLimit(1)
				Spacer()
				Text(chat.updatedAt, format: .relative(presentation: .named))
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Text(chat.preview)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(2)
			Text(chat.model.displayName)
				.font(.caption)
				.foregroundStyle(.tertiary)
		}
		.padding(.vertical, 4)
		.accessibilityElement(children: .combine)
	}
}

#Preview {
	List {
		ChatListRow(
			chat: ChatViewModel(
				messages: [
					ChatMessage(text: "Help me plan a trip", role: .user),
					ChatMessage(text: "Where would you like to go?", role: .assistant)
				]
			)
		)
	}
}
