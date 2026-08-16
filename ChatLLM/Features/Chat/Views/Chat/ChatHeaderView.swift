//
//  ChatHeaderView.swift
//  ChatHeaderView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatHeaderView: View {
	let model: ChatModel

	var body: some View {
		Label {
			Text(model.displayName)
				.font(.subheadline)
		} icon: {
			Image(systemName: model.availability.isAvailable ? "cpu" : "exclamationmark.triangle.fill")
				.foregroundStyle(.secondary)
		}
		.frame(maxWidth: .infinity, alignment: .leading)
		.padding(.horizontal)
		.padding(.vertical, 10)
		.background(.bar)
	}
}

#Preview {
	ChatHeaderView(
		model: ChatModel(
			id: "preview-model",
			displayName: "Apple Foundation Model",
			providerId: "apple",
			providerName: "Apple",
			summary: "Private, on-device responses for everyday tasks.",
			availability: .available
		)
	)
}
