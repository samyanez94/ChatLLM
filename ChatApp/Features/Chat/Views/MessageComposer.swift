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
		HStack(alignment: .bottom, spacing: 12) {
			TextField("Message", text: $draft, axis: .vertical)
				.lineLimit(1...5)
				.padding(.horizontal, 16)
				.padding(.vertical, 10)
				.background(.secondary.opacity(0.15))
				.clipShape(.rect(cornerRadius: 18))
				.submitLabel(.send)
				.onSubmit(send)

			Button("Send", systemImage: "arrow.up", action: send)
				.labelStyle(.iconOnly)
				.buttonStyle(.borderedProminent)
				.buttonBorderShape(.circle)
				.disabled(!canSend)
		}
		.padding()
	}
}
