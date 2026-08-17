//
//  ChatView.swift
//  ChatView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

struct ChatView: View {
	@State private var viewModel: ChatViewModel

	init(viewModel: ChatViewModel) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		@Bindable var viewModel = viewModel
		VStack(spacing: 0) {
			MessageList(
				messages: viewModel.messages,
				isResponding: viewModel.isResponding
			)
			Divider()
			MessageComposer(
				draft: $viewModel.draft,
				canSend: viewModel.canSend,
				send: sendMessage
			)
		}
		.navigationTitle("Chat")
		.navigationSubtitle(viewModel.model.displayName)
		.navigationBarTitleDisplayMode(.inline)
		.alert("Something went wrong", isPresented: $viewModel.isShowingError) {
		} message: {
			Text(viewModel.errorMessage ?? "")
		}
	}

	private func sendMessage() {
		Task {
			await viewModel.sendMessage()
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
