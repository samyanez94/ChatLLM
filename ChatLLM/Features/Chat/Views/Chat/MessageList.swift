//
//  MessageList.swift
//  MessageList
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct MessageList: View {
	/// How far the transcript can sit from the bottom while still following new content.
	private static let pinThreshold: CGFloat = 40

	let messages: [ChatMessage]

	let isResponding: Bool

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var scrollPosition = ScrollPosition(edge: .bottom)

	@State private var scrollPhase = ScrollPhase.idle

	@State private var isPinnedToBottom = true

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				ForEach(messages) { message in
					MessageBubble(message: message)
				}
				if isResponding {
					ProgressView()
						.frame(maxWidth: .infinity, alignment: .leading)
						.accessibilityLabel("Generating response")
				}
			}
			.padding()
		}
		.scrollPosition($scrollPosition)
		.defaultScrollAnchor(.bottom)
		.onScrollPhaseChange { _, phase in
			scrollPhase = phase
		}
		.onScrollGeometryChange(for: ScrollMetrics.self) { geometry in
			ScrollMetrics(geometry: geometry)
		} action: { previous, current in
			if current.hasSameLayout(as: previous) {
				// Nothing resized, so only a gesture can change whether the transcript follows new content.
				if isUserScrolling {
					isPinnedToBottom = current.distanceFromBottom <= Self.pinThreshold
				}
			} else if isPinnedToBottom {
				// The transcript or the visible area grew, so catch up with the new bottom.
				scrollToBottom()
			}
		}
		.onChange(of: messages.count) {
			isPinnedToBottom = true
			scrollToBottom()
		}
	}

	private var isUserScrolling: Bool {
		switch scrollPhase {
		case .tracking, .interacting, .decelerating:
			return true
		case .idle, .animating:
			return false
		@unknown default:
			return false
		}
	}

	private func scrollToBottom() {
		withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) {
			scrollPosition.scrollTo(edge: .bottom)
		}
	}
}

// MARK: - ScrollMetrics

/// A snapshot of the transcript's scroll geometry used to decide when to follow the bottom.
private struct ScrollMetrics: Equatable {
	let contentHeight: CGFloat

	let visibleHeight: CGFloat

	let distanceFromBottom: CGFloat

	init(geometry: ScrollGeometry) {
		contentHeight = geometry.contentSize.height
		visibleHeight = geometry.visibleRect.height
		distanceFromBottom = max(0, geometry.contentSize.height - geometry.visibleRect.maxY)
	}

	/// Whether the content and the visible area are unchanged, meaning only the offset moved.
	func hasSameLayout(as other: Self) -> Bool {
		contentHeight == other.contentHeight && visibleHeight == other.visibleHeight
	}
}
