//
//  ChatView.swift
//  ChatView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

struct ChatView: View {
    @Bindable var viewModel: ChatViewModel

    var body: some View {
        VStack(spacing: 0) {
            MessageList(
                messages: viewModel.messages,
                isResponding: viewModel.isResponding
            )
            Divider()
            MessageComposer(
                draft: $viewModel.draft,
                canSend: viewModel.canSend,
                send: { Task { await viewModel.sendMessage() } }
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
