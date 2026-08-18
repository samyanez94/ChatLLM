//
//  ProviderLogo.swift
//  ChatLLM
//
//  Created by ChatLLM on 8/17/26.

import SwiftUI

/// Displays the logo associated with a language-model provider.
struct ProviderLogo: View {
	let providerId: String

	var body: some View {
		imageResource
			.renderingMode(.template)
			.resizable()
			.scaledToFit()
			.frame(width: 22, height: 22)
			.accessibilityHidden(true)
	}

	private var imageResource: Image {
		switch providerId {
		case FoundationModelsChatService.providerId:
			Image(.appleLogo)
		case OpenAIModelCatalog.providerId:
			Image(.openaiLogo)
		case AnthropicModelCatalog.providerId:
			Image(.anthropicLogo)
		case GeminiModelCatalog.providerId:
			Image(.googleLogo)
		default:
			Image(systemName: "questionmark.square.dashed")
		}
	}
}

#Preview {
	HStack(spacing: 16) {
		ProviderLogo(providerId: FoundationModelsChatService.providerId)
		ProviderLogo(providerId: OpenAIModelCatalog.providerId)
		ProviderLogo(providerId: AnthropicModelCatalog.providerId)
		ProviderLogo(providerId: GeminiModelCatalog.providerId)
		ProviderLogo(providerId: "unknown")
	}
	.padding()
}
