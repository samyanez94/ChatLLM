//
//  ModelIndicatorView.swift
//  ModelIndicatorView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ModelIndicatorView: View {
	let modelName: String
	let availability: ChatModelAvailability

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: availability.isAvailable ? "cpu" : "exclamationmark.triangle.fill")
				.foregroundStyle(.secondary)

			VStack(alignment: .leading, spacing: 2) {
				Text(modelName)
					.font(.subheadline.weight(.medium))

				if let message = availability.unavailableMessage {
					Text(message)
						.font(.footnote)
						.foregroundStyle(.secondary)
				}
			}

			Spacer()
		}
		.padding(.horizontal)
		.padding(.vertical, 10)
		.background(.bar)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(accessibilityLabel)
	}

	private var accessibilityLabel: String {
		if let message = availability.unavailableMessage {
			"Current model: \(modelName). Unavailable. \(message)"
		} else {
			"Current model: \(modelName). Available."
		}
	}
}

#Preview {
	ModelIndicatorView(
		modelName: "Apple Foundation Model",
		availability: .available
	)
}
