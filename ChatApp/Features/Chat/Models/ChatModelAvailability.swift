//
//  ChatModelAvailability.swift
//  ChatModelAvailability
//
//  Created by Samuel Yanez on 8/14/26.

enum ChatModelAvailability: Equatable {
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
