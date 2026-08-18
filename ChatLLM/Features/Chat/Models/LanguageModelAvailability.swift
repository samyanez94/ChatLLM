//
//  LanguageModelAvailability.swift
//  LanguageModelAvailability
//
//  Created by Samuel Yanez on 8/14/26.

/// Describes whether a language model can currently generate responses.
enum LanguageModelAvailability: Equatable {
	case available
	case unavailable(message: String)

	var isAvailable: Bool {
		self == .available
	}

	var unavailableMessage: String? {
		guard case .unavailable(let message) = self else {
			return nil
		}
		return message
	}
}
