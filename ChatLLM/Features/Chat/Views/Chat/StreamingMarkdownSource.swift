//
//  StreamingMarkdownSource.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 10/12/26.
//

import SwiftStreamingMarkdown

/// Bridges cumulative response snapshots to the renderer without queueing stale text.
final class StreamingMarkdownSource: StreamedMarkdownSource {

	nonisolated let text: AsyncStream<String>

	private let continuation: AsyncStream<String>.Continuation

	init(text: String) {
		let stream = AsyncStream<String>.makeStream(bufferingPolicy: .bufferingNewest(1))
		self.text = stream.stream
		continuation = stream.continuation
		continuation.yield(text)
	}

	func update(_ text: String) {
		continuation.yield(text)
	}

	func finish() {
		continuation.finish()
	}

	deinit {
		continuation.finish()
	}
}
