//
//  ChatListView.swift
//  ChatListView
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct ChatListView: View {
	@State private var viewModel: ChatListViewModel

	let newChat: () -> Void

	init(
		viewModel: ChatListViewModel = ChatListViewModel(),
		newChat: @escaping () -> Void
	) {
		_viewModel = State(initialValue: viewModel)
		self.newChat = newChat
	}

	var body: some View {
		Group {
			if viewModel.chats.isEmpty {
				ContentUnavailableView {
					Label("No Chats", systemImage: "bubble.left.and.bubble.right")
				} description: {
					Text("Create a chat to start a conversation with a model.")
				}
			} else {
				List {
					ForEach(viewModel.chats) { chat in
						ChatListRow(chat: chat)
					}
					.onDelete(perform: viewModel.removeChats)
				}
			}
		}
		.navigationTitle("Chats")
		.toolbar {
			ToolbarItem(placement: .primaryAction) {
				Button("New Chat", systemImage: "square.and.pencil", action: newChat)
                    .buttonStyle(.glassProminent)
			}
		}
	}
}

#Preview("Empty") {
	NavigationStack {
		ChatListView(newChat: {})
	}
}

#Preview("Chats") {
	NavigationStack {
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
			),
			newChat: {}
		)
	}
}
