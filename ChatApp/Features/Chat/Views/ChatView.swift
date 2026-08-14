//
//  ChatView.swift
//  ChatView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatView: View {
	@State private var viewModel: ChatViewModel

	init(viewModel: ChatViewModel = ChatViewModel()) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		@Bindable var viewModel = viewModel

		NavigationStack {
			VStack(spacing: 0) {
				ModelIndicatorView(
					modelName: viewModel.model.displayName,
					availability: viewModel.model.availability
				)
				Divider()
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
			.navigationBarTitleDisplayMode(.inline)
			.alert("Something went wrong", isPresented: $viewModel.isShowingError) {
			} message: {
				Text(viewModel.errorMessage ?? "")
			}
		}
	}

	private func sendMessage() {
		Task {
			await viewModel.sendMessage()
		}
	}
}

#Preview {
	ChatView()
}
