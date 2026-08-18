//
//  ChatLLMAppTests.swift
//  ChatLLMTests
//

import SwiftData
import Testing

@testable import ChatLLM

@MainActor
struct ChatLLMAppTests {
	@Test("Model container creation failure is handled")
	func handlesModelContainerFailure() throws {
		let fallbackContainer = try ModelContainer(
			for: Schema(versionedSchema: ChatSchemaV1.self),
			migrationPlan: ChatMigrationPlan.self,
			configurations: ModelConfiguration(isStoredInMemoryOnly: true)
		)
		var receivedError: TestError?

		_ = ChatLLMApp(
			makeModelContainer: {
				throw TestError.modelContainerCreationFailed
			},
			onFailure: { error in
				receivedError = error as? TestError
				return fallbackContainer
			}
		)

		#expect(receivedError == .modelContainerCreationFailed)
	}
}

private enum TestError: Error, Equatable {
	case modelContainerCreationFailed
}
