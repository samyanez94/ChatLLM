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
		do {
			modelContainer = try ModelContainer(
				for: Schema(versionedSchema: ChatSchemaV1.self),
				migrationPlan: ChatMigrationPlan.self
			)
		} catch {
			fatalError("Failed to create the chat model container: \(error)")
		}
	}

	var body: some Scene {
		WindowGroup {
			ChatListView(modelContext: modelContainer.mainContext)
		}
		.modelContainer(modelContainer)
	}
}
