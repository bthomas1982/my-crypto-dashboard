import SwiftUI
import SwiftData

@main
struct MurmurApp: App {
    // One local store for the whole app. No account, no server — everything
    // lives on the device unless the user explicitly exports a note.
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(
                for: Recording.self, SummaryTemplate.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: false)
            )
            BuiltInTemplates.seedIfNeeded(in: container.mainContext)
        } catch {
            fatalError("Could not create the Murmur data store: \(error)")
        }
    }

    @State private var router = AIRouter()

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.coral)
                .environment(router)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    var body: some View {
        LibraryView()
    }
}
