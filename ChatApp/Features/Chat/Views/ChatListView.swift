//
//  ChatListView.swift
//  ChatListView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatListView: View {
	@State private var viewModel: ChatListViewModel
	@State private var path: [ChatViewModel.ID] = []
	@State private var isSelectingModel = false
	@State private var pendingChatId: ChatViewModel.ID?

	init(
		viewModel: ChatListViewModel = ChatListViewModel()
	) {
		_viewModel = State(initialValue: viewModel)
	}

	var body: some View {
		NavigationStack(path: $path) {
			Group {
				if viewModel.visibleChats.isEmpty {
					ContentUnavailableView {
						Label("No Chats", systemImage: "bubble.left.and.bubble.right")
					} description: {
						Text("Create a chat to start a conversation with a model.")
					}
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
			.onChange(of: path) {
				if path.isEmpty {
					viewModel.removeEmptyChats()
				}
			}
			.navigationTitle("Chats")
			.navigationDestination(for: ChatViewModel.ID.self) { chatID in
				if let chat = viewModel.chat(withID: chatID) {
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
					Button("New Chat", systemImage: "square.and.pencil", action: presentModelSelection)
						.buttonStyle(.glassProminent)
						.sheet(
							isPresented: $isSelectingModel,
							onDismiss: openPendingChat
						) {
							ModelSelectionView(
								models: viewModel.models,
								selectModel: selectModel
							)
							.presentationDetents([.medium, .large])
							.presentationDragIndicator(.visible)
						}
				}
			}
		}
	}

	private func presentModelSelection() {
		isSelectingModel = true
	}

	private func selectModel(_ model: ChatModel) {
		isSelectingModel = false
		pendingChatId = viewModel.createChat(using: model)?.id
	}

	private func openPendingChat() {
		guard let pendingChatId else {
			return
		}

		path.append(pendingChatId)
		self.pendingChatId = nil
	}
}

#Preview("Empty") {
	ChatListView()
}

#Preview("Chats") {
	ChatListView(
		viewModel: ChatListViewModel(
			chats: [
				ChatViewModel(
					messages: [
						ChatMessage(text: "Help me plan a trip", role: .user),
						ChatMessage(text: "Where would you like to go?", role: .assistant)
					]
				)
			]
		)
	)
}
