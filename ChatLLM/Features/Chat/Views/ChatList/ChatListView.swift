//
//  ChatListView.swift
//  ChatListView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftData
import SwiftUI

struct ChatListView: View {
    @Bindable var viewModel: ChatListViewModel
    
    @State private var path: [ChatViewModel.ID] = []
    
    @State private var isSelectingModel = false
    
    @State private var pendingChatId: ChatViewModel.ID?

    init(modelContext: ModelContext) {
        self.viewModel = ChatListViewModel(modelContext: modelContext)
    }

    init(viewModel: ChatListViewModel) {
        self.viewModel = viewModel
    }

    var body: some View {
        NavigationStack(path: $path) {
            Group {
                if viewModel.visibleChats.isEmpty {
                    ContentUnavailableView(
                        "No Chats",
                        systemImage: "bubble.left.and.bubble.right",
                        description: Text("Create a chat to start a conversation with a model.")
                    )
                } else {
                    List {
                        ForEach(viewModel.visibleChats) { chat in
                            NavigationLink(value: chat.id) {
                                ChatListRow(chat: chat)
                            }
                        }
                        .onDelete(perform: viewModel.removeChats)
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationDestination(for: ChatViewModel.ID.self) { chatId in
                if let chat = viewModel.chat(withId: chatId) {
                    ChatView(viewModel: chat)
                } else {
                    ContentUnavailableView(
                        "Chat Not Found",
                        systemImage: "bubble.left",
                        description: Text("This chat is no longer available.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("New Chat", systemImage: "square.and.pencil") {
                        isSelectingModel = true
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .sheet(isPresented: $isSelectingModel, onDismiss: openPendingChat) {
                ModelSelectionView(
                    models: viewModel.models,
                    selectModel: selectModel
                )
            }
        }
        .onChange(of: path) {
            if path.isEmpty {
                viewModel.removeEmptyChats()
            }
        }
        .alert(
            "Chat History Unavailable",
            isPresented: $viewModel.isShowingError
        ) {
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
    }

    private func selectModel(_ model: LanguageModel) {
        guard let chat = viewModel.createChat(using: model) else {
            return
        }
        pendingChatId = chat.id
        isSelectingModel = false
    }

    private func openPendingChat() {
        guard let id = pendingChatId else {
            return
        }
        path.append(id)
        pendingChatId = nil
    }
}

#Preview("Empty") {
    let container = PreviewContainer.make()

    ChatListView(modelContext: container.mainContext)
        .modelContainer(container)
}

#Preview("Chats") {
    let container = PreviewContainer.make(
        chats: [
            Chat(
                providerId: FoundationModelsChatService.providerId,
                modelId: FoundationModelsChatService.modelId,
                messages: [
                    ChatMessage(sequence: 0, text: "Help me plan a trip", role: .user),
                    ChatMessage(sequence: 1, text: "Where would you like to go?", role: .assistant)
                ]
            )
        ]
    )

    ChatListView(modelContext: container.mainContext)
        .modelContainer(container)
}
