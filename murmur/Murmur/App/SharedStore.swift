import Foundation
import SwiftData

/// A single ModelContainer shared by the SwiftUI app *and* App Intents (which run
/// outside the view hierarchy). Keeping it in one place means a Shortcut can read
/// your recordings using the exact same store the app writes to.
enum SharedStore {
    /// Flip to `true` after adding the iCloud + CloudKit capability in Xcode to
    /// sync recordings across the user's devices. Left off by default so the app
    /// builds and runs with a free personal team and no paid account.
    static let enableCloudSync = false

    static let container: ModelContainer = {
        let schema = Schema([Recording.self, Summary.self, SummaryTemplate.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: enableCloudSync ? .automatic : .none
        )
        do {
            return try ModelContainer(for: schema, configurations: config)
        } catch {
            fatalError("Could not create the Murmur data store: \(error)")
        }
    }()

    /// Seed built-in templates. Must run on the main actor (mainContext is
    /// main-actor-isolated); call once at app launch.
    @MainActor
    static func seedTemplatesIfNeeded() {
        BuiltInTemplates.seedIfNeeded(in: container.mainContext)
    }
}
