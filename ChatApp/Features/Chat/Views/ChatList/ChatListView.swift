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

	init(viewModel: ChatListViewModel = ChatListViewModel()) {
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
					Button("New Chat", systemImage: "square.and.pencil", action: presentModelSelection)
						.buttonStyle(.borderedProminent)
						.sheet(
							isPresented: $isSelectingModel,
							onDismiss: openPendingChat
						) {
							ModelSelectionView(
								models: viewModel.models,
								selectModel: selectModel
							)
						}
				}
			}
		}
	}

	private func presentModelSelection() {
		isSelectingModel = true
	}

	private func selectModel(_ model: ChatModel) {
		guard let chat = viewModel.createChat(using: model) else {
			return
		}

		pendingChatId = chat.id
		isSelectingModel = false
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
