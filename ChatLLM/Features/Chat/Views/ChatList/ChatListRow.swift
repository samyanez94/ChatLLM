//
//  ChatListRow.swift
//  ChatListRow
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

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
            HStack(spacing: 4) {
                Text(chat.updatedAt, format: .relative(presentation: .named))
                Text("•")
                Text(chat.model.displayName)
                Spacer()
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    let container = PreviewContainer.make()

    List {
        ChatListRow(
            chat: ChatViewModel(
                messages: [
                    ChatMessage(sequence: 0, text: "Help me plan a trip", role: .user),
                    ChatMessage(sequence: 1, text: "Where would you like to go?", role: .assistant)
                ],
                modelContext: container.mainContext
            )
        )
    }
    .modelContainer(container)
}
