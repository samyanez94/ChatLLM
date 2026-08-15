//
//  ModelSelectionView.swift
//  ModelSelectionView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ModelSelectionView: View {
	@Environment(\.dismiss) private var dismiss

	let models: [ChatModel]

	let selectModel: (ChatModel) -> Void

	var body: some View {
		NavigationStack {
			List(models) { model in
				Button {
					selectModel(model)
				} label: {
					ModelSelectionRow(model: model)
				}
				.buttonStyle(.plain)
				.disabled(!model.availability.isAvailable)
			}
			.navigationTitle("Choose a Model")
			.navigationBarTitleDisplayMode(.inline)
			.toolbar {
				ToolbarItem(placement: .cancellationAction) {
					Button("Close", systemImage: "xmark", action: dismiss.callAsFunction)
						.labelStyle(.iconOnly)
				}
			}
		}
	}
}

#Preview {
	ModelSelectionView(
		models: ChatProviderFactory().models,
		selectModel: { _ in }
	)
}
