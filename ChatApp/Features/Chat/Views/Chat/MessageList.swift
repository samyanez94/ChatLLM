//
//  MessageList.swift
//  MessageList
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct MessageList: View {
	private static let progressId = "generating-response"

	let messages: [ChatMessage]
	let isResponding: Bool

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView {
				LazyVStack(spacing: 12) {
					ForEach(messages) { message in
						MessageBubble(message: message)
							.id(message.id)
					}
					if isResponding {
						ProgressView()
							.frame(maxWidth: .infinity, alignment: .leading)
							.id(Self.progressId)
							.accessibilityLabel("Generating response")
					}
				}
				.padding()
			}
			.defaultScrollAnchor(.bottom)
			.onChange(of: messages.count) {
				scrollToLatestMessage(using: proxy)
			}
			.onChange(of: isResponding) {
				scrollToLatestMessage(using: proxy)
			}
		}
	}

	private func scrollToLatestMessage(using proxy: ScrollViewProxy) {
		let target: AnyHashable? = isResponding ? Self.progressId : messages.last?.id

		guard let target else {
			return
		}

		if reduceMotion {
			proxy.scrollTo(target, anchor: .bottom)
		} else {
			withAnimation {
				proxy.scrollTo(target, anchor: .bottom)
			}
		}
	}
}
