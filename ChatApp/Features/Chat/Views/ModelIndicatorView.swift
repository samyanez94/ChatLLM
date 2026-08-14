//
//  ModelIndicatorView.swift
//  ModelIndicatorView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ModelIndicatorView: View {
	let modelName: String

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: "cpu")
				.foregroundStyle(.secondary)
			Text(modelName)
				.font(.subheadline.weight(.medium))
			Spacer()
		}
		.padding(.horizontal)
		.padding(.vertical, 10)
		.background(.bar)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel("Current model: \(modelName)")
	}
}

#Preview {
	ModelIndicatorView(modelName: "Apple Foundation Model")
}
