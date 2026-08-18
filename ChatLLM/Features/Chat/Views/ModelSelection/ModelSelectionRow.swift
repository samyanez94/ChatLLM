//
//  ModelSelectionRow.swift
//  ModelSelectionRow
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ModelSelectionRow: View {
    let model: LanguageModel

    var body: some View {
        HStack(spacing: 12) {
            ProviderLogo(providerId: model.providerId)
            VStack(alignment: .leading, spacing: 4) {
                Text(model.displayName)
                    .font(.headline)
                Text(model.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let message = model.availability.unavailableMessage {
                    Text(message)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer()
            if model.availability.isAvailable {
                Image(systemName: "chevron.right")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
