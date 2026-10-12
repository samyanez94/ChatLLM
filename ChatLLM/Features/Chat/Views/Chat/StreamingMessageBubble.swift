//
//  StreamingMessageBubble.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 10/11/26.
//

import SwiftUI

/// Keeps a live renderer mounted through completion; restored history uses static Markdown.
struct StreamingMessageBubble: View {

	let text: String

	let isStreaming: Bool

	let status: ChatMessageStatus

	let isStopping: Bool

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var source: StreamingMarkdownSource?

	private var bypass: Bool {
		reduceMotion || isStopping || status != .completed
	}

	var body: some View {
		MessageBubble(
			text: text,
			role: .assistant,
			status: status,
			streamSource: bypass ? nil : source
		)
		.task(id: bypass) {
			source?.finish()
			source = nil
			guard isStreaming,
                  !bypass else {
                return
            }
			source = StreamingMarkdownSource(text: text)
		}
		.onChange(of: text) { _, text in
			source?.update(text)
		}
		.onChange(of: isStreaming) { _, isStreaming in
			if !isStreaming {
				// Deliver the final snapshot before ending the sequence, without replacing the view.
				source?.update(text)
				source?.finish()
			}
		}
		.onDisappear {
			source?.finish()
			source = nil
		}
	}
}
