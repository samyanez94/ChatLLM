//
//  MessageBubble.swift
//  MessageBubble
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 48)
            }
            Text(message.text)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(backgroundStyle)
                .foregroundStyle(foregroundStyle)
                .clipShape(.rect(cornerRadius: 18))
                .accessibilityLabel("\(speakerName): \(message.text)")

            if message.role == .assistant {
                Spacer(minLength: 48)
            }
        }
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
}
