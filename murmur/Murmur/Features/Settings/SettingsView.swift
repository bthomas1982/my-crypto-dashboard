import SwiftUI

/// Where the buyer plugs in their own AI. The whole "bring your own brain" model
/// lives here: pick a provider, and for the key-based ones paste a key that
/// never leaves the Keychain.
struct SettingsView: View {
    @Environment(AIRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        @Bindable var router = router
        NavigationStack {
            Form {
                providerSection(router: router)
                keySection(router: router)
                Section {
                    NavigationLink {
                        TemplatesView()
                    } label: {
                        Label("Summary templates", systemImage: "doc.badge.gearshape")
                    }
                    NavigationLink {
                        PackStoreView()
                    } label: {
                        Label("Template packs", systemImage: "bag")
                    }
                }
                syncSection
                privacySection
                aboutSection
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func providerSection(router: AIRouter) -> some View {
        Section {
            Picker("AI provider", selection: Binding(
                get: { router.provider },
                set: { router.provider = $0 }
            )) {
                ForEach(AIRouter.Provider.allCases) { provider in
                    Text(provider.label).tag(provider)
                }
            }
            Text(router.provider.blurb)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Brain")
        } footer: {
            Text("Apple's on-device model is free and private — no key required. Choose Claude or OpenAI to use your own account for higher-quality summaries.")
        }
    }

    @ViewBuilder private func keySection(router: AIRouter) -> some View {
        switch router.provider {
        case .apple:
            EmptyView()
        case .claude:
            APIKeyEditor(
                title: "Anthropic API key",
                account: ClaudeEngine.keyAccount,
                model: Binding(get: { router.claudeModel }, set: { router.claudeModel = $0 }),
                modelHint: "e.g. \(ClaudeEngine.modelDefault)",
                footnote: "Get a key at console.anthropic.com. This is pay-as-you-go API billing — separate from a Claude.ai Pro/Max chat subscription. Typically pennies per summary."
            )
        case .openai:
            APIKeyEditor(
                title: "OpenAI API key",
                account: OpenAIEngine.keyAccount,
                model: Binding(get: { router.openAIModel }, set: { router.openAIModel = $0 }),
                modelHint: "e.g. \(OpenAIEngine.modelDefault)",
                footnote: "Works with OpenAI or any compatible endpoint (OpenRouter, Azure, a local server)."
            )
        }
    }

    private var syncSection: some View {
        Section {
            LabeledContent("iCloud sync", value: SharedStore.enableCloudSync ? "On" : "Off")
        } footer: {
            Text(SharedStore.enableCloudSync
                 ? "Recordings sync privately across your devices via your own iCloud. Nothing passes through us."
                 : "Recordings stay on this device. Enable iCloud sync in a build with the iCloud capability turned on.")
        }
    }

    private var privacySection: some View {
        Section {
            Label {
                Text("Your audio and transcripts stay on this iPhone. Only the transcript text you choose to summarize is sent — directly from your phone to your selected AI provider, using your key.")
            } icon: {
                Image(systemName: "lock.shield").foregroundStyle(Theme.good)
            }
            .font(.footnote)
        } header: {
            Text("Privacy")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("Version", value: "0.1.0")
            LabeledContent("Transcription", value: "On-device (iOS Speech)")
        } footer: {
            Text("Murmur — capture on your phone, think with your AI. One-time purchase, no subscription.")
        }
    }
}

/// Secure key entry backed by the Keychain, plus an editable model id.
private struct APIKeyEditor: View {
    let title: String
    let account: String
    @Binding var model: String
    let modelHint: String
    let footnote: String

    @State private var key: String = ""
    @State private var saved = false

    var body: some View {
        Section {
            SecureField(saved || KeychainStore.exists(account) ? "•••• stored in Keychain" : "Paste key", text: $key)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(Theme.mono(14))
            HStack {
                Button("Save key") {
                    KeychainStore.set(key, for: account)
                    key = ""
                    saved = true
                }
                .disabled(key.isEmpty)
                if KeychainStore.exists(account) || saved {
                    Spacer()
                    Button("Remove", role: .destructive) {
                        KeychainStore.set(nil, for: account)
                        saved = false
                    }
                }
            }
            TextField("Model", text: $model)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .font(Theme.mono(14))
        } header: {
            Text(title)
        } footer: {
            Text(footnote + "\n\nModel — \(modelHint). Editable so you can point at the newest model without an app update.")
        }
    }
}
