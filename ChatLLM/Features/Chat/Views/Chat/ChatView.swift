//
//  ChatView.swift
//  ChatView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

struct ChatView: View {

	@Environment(\.scenePhase) private var scenePhase

	@Bindable var viewModel: ChatViewModel

	@FocusState private var isComposerFocused: Bool

	var body: some View {
		VStack(spacing: 0) {
			MessageList(
				messages: viewModel.messages,
				isResponding: viewModel.isResponding,
				streamingText: viewModel.streamingText,
				responseID: viewModel.responseID,
				isStopping: viewModel.isStopping
			)
			.simultaneousGesture(
				TapGesture()
					.onEnded {
						isComposerFocused = false
					}
			)
			Divider()
			MessageComposer(
				draft: $viewModel.draft,
				canSend: viewModel.canSend,
				isResponding: viewModel.isResponding,
				stop: viewModel.stopResponse,
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
		.onDisappear {
			viewModel.interruptResponse()
		}
		.onChange(of: scenePhase) { _, phase in
			if phase == .background {
				viewModel.interruptResponse()
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
