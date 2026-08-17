//
//  ModelSelectionView.swift
//  ModelSelectionView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ModelSelectionView: View {
	@Environment(\.dismiss) private var dismiss

	let models: [LanguageModel]
	let selectModel: (LanguageModel) -> Void

	var body: some View {
		NavigationStack {
			List {
				ForEach(providerIds, id: \.self) { providerId in
					Section(providerName(for: providerId)) {
						ForEach(models(for: providerId)) { model in
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

	private var providerIds: [String] {
		models.reduce(into: []) { providerIds, model in
			guard providerIds.contains(model.providerId) == false else {
				return
			}
			providerIds.append(model.providerId)
		}
	}

	private func providerName(for providerId: String) -> String {
		models.first { $0.providerId == providerId }?.providerName ?? providerId
	}

	private func models(for providerId: String) -> [LanguageModel] {
		models.filter { $0.providerId == providerId }
	}
}

#Preview {
	ModelSelectionView(
		models: ChatProviderFactory().models,
		selectModel: { _ in }
	)
}
