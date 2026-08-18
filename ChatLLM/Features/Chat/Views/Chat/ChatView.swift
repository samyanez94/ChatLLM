//
//  ChatView.swift
//  ChatView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

struct ChatView: View {
	@Bindable var viewModel: ChatViewModel
	@FocusState private var isComposerFocused: Bool

	var body: some View {
		VStack(spacing: 0) {
			MessageList(
				messages: viewModel.messages,
				isResponding: viewModel.isResponding
			)
			.simultaneousGesture(
				TapGesture().onEnded {
					isComposerFocused = false
				}
			)
			Divider()
			MessageComposer(
				draft: $viewModel.draft,
				canSend: viewModel.canSend,
				isFocused: $isComposerFocused,
				send: { Task { await viewModel.sendMessage() } }
			)
		}
		.navigationTitle("Chat")
		.navigationSubtitle(viewModel.model.displayName)
		.navigationBarTitleDisplayMode(.inline)
		.onAppear {
			if viewModel.messages.isEmpty {
				isComposerFocused = true
			}
		}
		.alert("Something went wrong", isPresented: $viewModel.isShowingError) {
		} message: {
			Text(viewModel.errorMessage ?? "")
		}
	}
}

#Preview {
	let container = PreviewContainer.make()

	NavigationStack {
		ChatView(
			viewModel: ChatViewModel(modelContext: container.mainContext)
		)
	}
	.modelContainer(container)
}
