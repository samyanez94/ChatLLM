//
//  PreviewContainer.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.

import SwiftData

/// Creates isolated, in-memory persistence for SwiftUI previews.
enum PreviewContainer {
	@MainActor
	static func make() -> ModelContainer {
		do {
			return try ModelContainer(
				for: Schema(versionedSchema: ChatSchemaV1.self),
				migrationPlan: ChatMigrationPlan.self,
				configurations: ModelConfiguration(isStoredInMemoryOnly: true)
			)
		} catch {
			fatalError("Failed to create the preview model container: \(error)")
		}
	}
}
