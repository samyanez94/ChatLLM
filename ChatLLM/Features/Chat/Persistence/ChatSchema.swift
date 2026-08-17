//
//  ChatSchema.swift
//  ChatLLM
//
//  Created by Samuel Yanez on 8/16/26.

import SwiftData

/// The first version of the on-device chat persistence schema.
enum ChatSchemaV1: VersionedSchema {
	static let versionIdentifier = Schema.Version(1, 0, 0)

	static var models: [any PersistentModel.Type] {
		[Chat.self, ChatMessage.self]
	}
}

/// Defines the supported chat schema versions and migrations between them.
enum ChatMigrationPlan: SchemaMigrationPlan {
	static var schemas: [any VersionedSchema.Type] {
		[ChatSchemaV1.self]
	}

	static var stages: [MigrationStage] {
		[]
	}
}
