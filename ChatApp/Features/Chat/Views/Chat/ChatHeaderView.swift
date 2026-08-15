//
//  ChatHeaderView.swift
//  ChatHeaderView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatHeaderView: View {
	let model: ChatModel

	var body: some View {
		HStack {
			Label {
				VStack(alignment: .leading, spacing: 2) {
					Text(model.displayName)
						.font(.subheadline.weight(.medium))

					if let message = model.availability.unavailableMessage {
						Text(message)
							.font(.footnote)
							.foregroundStyle(.secondary)
					}
				}
			} icon: {
				Image(systemName: model.availability.isAvailable ? "cpu" : "exclamationmark.triangle.fill")
					.foregroundStyle(.secondary)
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
		if let message = model.availability.unavailableMessage {
			"Current model: \(model.displayName). Unavailable. \(message)"
		} else {
			"Current model: \(model.displayName). Available."
		}
	}
}

#Preview {
	ChatHeaderView(
		model: ChatModel(
			id: "preview-model",
			displayName: "Apple Foundation Model",
			providerName: "Apple",
			availability: .available
		)
	)
}
