//
//  StreamingMarkdownSourceTests.swift
//  ChatLLMTests
//
//  Created by Samuel Yanez on 10/12/26.
//

@testable import ChatLLM
import Testing

@MainActor
struct StreamingMarkdownSourceTests {
	@Test("The renderer receives the initial snapshot and subsequent full snapshots")
	func snapshots() async {
		let source = StreamingMarkdownSource(text: "Hello")
		var iterator = source.text.makeAsyncIterator()
		#expect(await iterator.next() == "Hello")
		source.update("Hello world")
		source.finish()
		#expect(await iterator.next() == "Hello world")
		#expect(await iterator.next() == nil)
	}

	@Test("A slow renderer receives the newest snapshot, including final text after completion")
	func boundedBuffer() async {
		let source = StreamingMarkdownSource(text: "First")
		source.update("First and second")
		source.update("First and second and last")
		source.finish()
		source.update("Ignored after completion")
		var iterator = source.text.makeAsyncIterator()
		#expect(await iterator.next() == "First and second and last")
		#expect(await iterator.next() == nil)
	}
}
