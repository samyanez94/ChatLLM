//
//  ChatLLMApp.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

@main
struct ChatLLMApp: App {
	private let modelContainer: ModelContainer

	init() {
		self.init(
			makeModelContainer: {
				try ModelContainer(
					for: Schema(versionedSchema: ChatSchemaV1.self),
					migrationPlan: ChatMigrationPlan.self
				)
			},
			onFailure: { error in
				fatalError("Failed to create the chat model container: \(error)")
			}
		)
	}

	init(
		makeModelContainer: () throws -> ModelContainer,
		onFailure: (any Error) -> ModelContainer
	) {
		do {
			modelContainer = try makeModelContainer()
		} catch {
			modelContainer = onFailure(error)
		}
	}

	var body: some Scene {
		WindowGroup {
			ChatListView(modelContext: modelContainer.mainContext)
		}
		.modelContainer(modelContainer)
	}
}
