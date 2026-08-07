import SwiftUI

/// Chat with a single recording. Answers are grounded in its transcript and run
/// through the user's selected brain (on-device or their own key).
struct AskNotesView: View {
    let transcript: String
    @Environment(AIRouter.self) private var router
    @Environment(\.dismiss) private var dismiss
    @State private var convo: NotesConversation?
    @State private var draft = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 14) {
                            if let convo, convo.messages.isEmpty {
                                Starters { starter in
                                    Task { await convo.ask(starter) }
                                }
                            }
                            ForEach(convo?.messages ?? []) { message in
                                Bubble(message: message).id(message.id)
                            }
                            if convo?.isThinking == true {
                                Bubble(message: ChatMessage(role: .assistant, text: "…"))
                                    .redacted(reason: .placeholder)
                            }
                        }
                        .padding()
                    }
                    .onChange(of: convo?.messages.count) {
                        if let last = convo?.messages.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                }
                if let error = convo?.errorMessage {
                    Text(error).font(.footnote).foregroundStyle(Theme.warn)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal)
                }
                composer
            }
            .navigationTitle("Ask your notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text(router.provider.label).font(Theme.mono(11)).foregroundStyle(.secondary)
                }
            }
            .onAppear { if convo == nil { convo = NotesConversation(transcript: transcript, router: router) } }
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            TextField("Ask about this recording…", text: $draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(Color(.secondarySystemBackground), in: Capsule())
                .lineLimit(1...4)
            Button {
                let q = draft; draft = ""
                Task { await convo?.ask(q) }
            } label: {
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30))
            }
            .disabled(draft.trimmingCharacters(in: .whitespaces).isEmpty || convo?.isThinking == true)
        }
        .padding(12)
        .background(.bar)
    }
}

private struct Bubble: View {
    let message: ChatMessage
    var isUser: Bool { message.role == .user }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 40) }
            Text(LocalizedStringKey(message.text))
                .textSelection(.enabled)
                .padding(.horizontal, 14).padding(.vertical, 10)
                .background(
                    isUser ? AnyShapeStyle(Theme.coral) : AnyShapeStyle(Color(.secondarySystemBackground)),
                    in: RoundedRectangle(cornerRadius: 16)
                )
                .foregroundStyle(isUser ? .white : .primary)
            if !isUser { Spacer(minLength: 40) }
        }
    }
}

private struct Starters: View {
    let onPick: (String) -> Void
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Try asking").font(Theme.mono(12)).foregroundStyle(.secondary)
            ForEach(NotesConversation.starters, id: \.self) { starter in
                Button { onPick(starter) } label: {
                    HStack {
                        Image(systemName: "sparkle").foregroundStyle(Theme.coral)
                        Text(starter).foregroundStyle(.primary)
                        Spacer()
                    }
                    .padding(.horizontal, 14).padding(.vertical, 12)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }
}
