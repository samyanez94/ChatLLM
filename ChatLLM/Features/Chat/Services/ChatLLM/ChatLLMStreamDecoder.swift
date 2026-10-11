//
//  ChatLLMStreamDecoder.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 10/11/26.
//

import Foundation

/// Decodes bounded SSE frames and validates the backend's terminal event.
nonisolated struct ChatLLMStreamDecoder {

	private let provider: String

	private let model: String

	private var line = Data()

	private var event = ""

	private var data = [String]()

	private var frameBytes = 0

	private var afterCR = false

	private(set) var text = ""

	private(set) var isComplete = false

	init(provider: String, model: String) {
		self.provider = provider
		self.model = model
	}

	/// Returns true when visible text changes. CRLF may span network reads.
	mutating func append(_ byte: UInt8) throws -> Bool {
		guard !isComplete else {
			throw ChatLLMClientError.invalidResponsePayload
		}
		if afterCR && byte == 10 {
			afterCR = false
			return false
		}
		afterCR = byte == 13
		if byte != 10 && byte != 13 {
			frameBytes += 1
			guard frameBytes <= 1_048_576 else {
				throw ChatLLMClientError.invalidResponsePayload
			}
			line.append(byte)
			return false
		}
		guard let value = String(data: line, encoding: .utf8) else {
			throw ChatLLMClientError.invalidResponsePayload
		}
		line.removeAll(keepingCapacity: true)
		if value.isEmpty {
			defer {
				event = ""
				data = []
				frameBytes = 0
			}
			guard !data.isEmpty else {
				return false
			}
			return try decodeEvent()
		}
		if value.hasPrefix(":") {
			return false
		}
		let fields = value.split(
			separator: ":",
			maxSplits: 1,
			omittingEmptySubsequences: false
		)
		var content = fields.count == 2 ? String(fields[1]) : ""
		if content.hasPrefix(" ") {
			content.removeFirst()
		}
		switch fields[0] {
		case "event":
			event = content
		case "data":
			data.append(content)
		default:
			break
		}
		return false
	}

	func finish() throws {
		guard isComplete else { throw ChatLLMClientError.incompleteStream }
	}

	private mutating func decodeEvent() throws -> Bool {
		let payload = Data(data.joined(separator: "\n").utf8)
		do {
			switch event {
			case "delta":
				let delta = try JSONDecoder().decode(Delta.self, from: payload)
				text += delta.text
				return !delta.text.isEmpty
			case "completed":
				let completed = try JSONDecoder().decode(Completed.self, from: payload)
				guard completed.provider == provider,
					completed.model == model,
					!text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
				else {
					throw ChatLLMClientError.invalidResponsePayload
				}
				isComplete = true
				return false
			case "error":
				let envelope = try JSONDecoder().decode(Failure.self, from: payload)
				throw ChatLLMClientError.streamFailed(envelope.error)
			default:
				throw ChatLLMClientError.invalidResponsePayload
			}
		} catch let error as ChatLLMClientError {
			throw error
		} catch {
			throw ChatLLMClientError.invalidResponsePayload
		}
	}

	private struct Delta: Decodable {
		let text: String
	}

	private struct Completed: Decodable {
		let provider: String
		let model: String
	}

	private struct Failure: Decodable {
		let error: ChatLLMAPIError
	}
}
