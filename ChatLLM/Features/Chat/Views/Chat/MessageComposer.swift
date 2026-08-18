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
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Message", text: $draft, axis: .vertical)
                .lineLimit(1...5)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(.fill.tertiary, in: .rect(cornerRadius: 18))
                .submitLabel(.send)
                .onSubmit(send)
            Button(action: send) {
                Image(systemName: "arrow.up")
                    .bold()
                    .padding(5)
            }
            .buttonStyle(.borderedProminent)
            .buttonBorderShape(.circle)
            .disabled(!canSend)
        }
        .padding()
    }
}
