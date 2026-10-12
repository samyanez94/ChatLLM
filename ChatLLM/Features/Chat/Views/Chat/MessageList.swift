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

	var streamingText = ""

	var responseID: UUID?

	var isStopping = false

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	@State private var scrollPosition = ScrollPosition(edge: .bottom)

	@State private var scrollPhase = ScrollPhase.idle

	@State private var isPinnedToBottom = true

	var body: some View {
		ScrollView {
			LazyVStack(spacing: 12) {
				ForEach(rows) { row in
					if row.role == .assistant {
						StreamingMessageBubble(
							text: row.text,
							isStreaming: row.isStreaming,
							status: row.status,
							isStopping: row.id == responseID && isStopping
						)
					} else {
						MessageBubble(text: row.text, role: row.role)
					}
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
			if isUserScrolling {
				// Gestures take priority even while new text changes the content height.
				isPinnedToBottom = current.distanceFromBottom <= Self.pinThreshold
			} else if !current.hasSameLayout(as: previous) && isPinnedToBottom {
				scrollToBottom()
			}
		}
		.onChange(of: messages.count) {
			if messages.last?.role == .user { isPinnedToBottom = true }
			if isPinnedToBottom { scrollToBottom() }
		}
	}

	// One row identity survives the transition from a live reply to its saved message.
	private var rows: [MessageRow] {
		var rows = messages.map {
			MessageRow(id: $0.id, text: $0.text, role: $0.role, status: $0.status)
		}
		if isResponding,
			let responseID,
			!streamingText.isEmpty,
			!rows.contains(where: { $0.id == responseID })
		{
			rows.append(
				MessageRow(
					id: responseID,
					text: streamingText,
					role: .assistant,
					isStreaming: true
				)
			)
		}
		return rows
	}

	private struct MessageRow: Identifiable {
		let id: UUID
		let text: String
		let role: ChatMessageRole
		var status: ChatMessageStatus = .completed
		var isStreaming = false
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
		withAnimation(reduceMotion || isResponding ? nil : .smooth(duration: 0.25)) {
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
