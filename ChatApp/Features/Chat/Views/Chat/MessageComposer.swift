//
//  MessageComposer.swift
//  MessageComposer
//
//  Created by Samuel Yanez on 8/14/26.

import SwiftUI

struct MessageComposer: View {
	@Binding var draft: String
	let canSend: Bool
	let send: () -> Void

	var body: some View {
		HStack(alignment: .center, spacing: 12) {
			TextField("Message", text: $draft, axis: .vertical)
				.lineLimit(1...5)
				.padding(.horizontal, 16)
				.padding(.vertical, 10)
				.frame(minHeight: 44, alignment: .leading)
				.background(.secondary.opacity(0.15))
				.clipShape(.rect(cornerRadius: 18))
				.submitLabel(.send)
				.onSubmit(send)
			Button(action: send) {
				Label("Send", systemImage: "arrow.up")
					.labelStyle(.iconOnly)
					.padding(.vertical, 10)
			}
			.buttonStyle(.borderedProminent)
			.buttonBorderShape(.circle)
			.frame(minWidth: 44, minHeight: 44)
			.contentShape(.circle)
			.disabled(!canSend)
		}
		.padding()
	}
}
