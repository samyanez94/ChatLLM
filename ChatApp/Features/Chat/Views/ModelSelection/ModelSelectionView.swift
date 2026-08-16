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
			List {
				ForEach(providerNames, id: \.self) { providerName in
					Section(providerName) {
						ForEach(models(for: providerName)) { model in
							Button {
								selectModel(model)
							} label: {
								ModelSelectionRow(model: model)
							}
							.buttonStyle(.plain)
							.disabled(!model.availability.isAvailable)
						}
					}
				}
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

	private var providerNames: [String] {
		models.reduce(into: []) { providerNames, model in
			guard providerNames.contains(model.providerName) == false else {
				return
			}
			providerNames.append(model.providerName)
		}
	}

	private func models(for providerName: String) -> [ChatModel] {
		models.filter { $0.providerName == providerName }
	}
}

#Preview {
	ModelSelectionView(
		models: ChatProviderFactory().models,
		selectModel: { _ in }
	)
}
