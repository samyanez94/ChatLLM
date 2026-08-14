//
//  ChatModelAvailability.swift
//  ChatModelAvailability
//
//  Created by Samuel Yanez on 8/14/26.

/// The current availability of a chat model.
enum ChatModelAvailability: Equatable {
	/// The model is ready to generate responses.
	case available

	/// The model cannot generate responses, accompanied by a user-facing explanation.
	case unavailable(message: String)

	/// Whether the model is ready to generate responses.
	var isAvailable: Bool {
		self == .available
	}

	/// A user-facing explanation when the model is unavailable.
	var unavailableMessage: String? {
		guard case .unavailable(let message) = self else {
			return nil
		}

		return message
	}
}
