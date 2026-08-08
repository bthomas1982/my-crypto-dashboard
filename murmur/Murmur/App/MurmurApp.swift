import SwiftUI
import SwiftData

@main
struct MurmurApp: App {
    // One local store shared with App Intents. No account, no server — everything
    // lives on the device unless the user explicitly exports a note.
    @State private var router = AIRouter()
    @State private var store = StoreManager()
    @AppStorage("hasOnboarded") private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            RootView(hasOnboarded: $hasOnboarded)
                .tint(Theme.coral)
                .environment(router)
                .environment(store)
                .task { SharedStore.seedTemplatesIfNeeded() }
                .task { await store.start() }
        }
        .modelContainer(SharedStore.container)
    }
}

struct RootView: View {
    @Binding var hasOnboarded: Bool
    var body: some View {
        if hasOnboarded {
            LibraryView()
        } else {
            OnboardingView { hasOnboarded = true }
        }
    }
}
