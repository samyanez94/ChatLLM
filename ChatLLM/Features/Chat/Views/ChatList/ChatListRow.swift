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
			Text(chat.title)
				.font(.headline)
				.lineLimit(1)
			Text(chat.preview)
				.font(.subheadline)
				.foregroundStyle(.secondary)
				.lineLimit(2)
			Text("Last updated \(chat.updatedAt, format: .relative(presentation: .named))")
				.font(.caption)
				.foregroundStyle(.tertiary)
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
					ChatMessage(sequence: 0, text: "Help me plan a trip", role: .user),
					ChatMessage(
						sequence: 1,
						text: "Where would you like to go?",
						role: .assistant
					)
				]
			)
		)
	}
}
