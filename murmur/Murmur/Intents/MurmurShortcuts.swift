import AppIntents
import SwiftData

/// Siri / Shortcuts entry points. These are the "agentic" edge from the spec:
/// a recording becomes a finished thing (a summary, a drafted email) without
/// opening the app — "Hey Siri, summarize my last recording."
enum MurmurIntentError: Error, CustomLocalizedStringResourceConvertible {
    case noRecording
    case noTranscript
    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noRecording: return "You don't have any recordings yet."
        case .noTranscript: return "Your most recent recording doesn't have a transcript."
        }
    }
}

/// Run a named template against the most recent recording and save the result.
@MainActor
private func summarizeLatest(using templateName: String) async throws -> String {
    let context = SharedStore.container.mainContext

    var descriptor = FetchDescriptor<Recording>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
    descriptor.fetchLimit = 1
    guard let recording = try context.fetch(descriptor).first else { throw MurmurIntentError.noRecording }
    guard recording.hasTranscript else { throw MurmurIntentError.noTranscript }

    let instructions = templateInstructions(named: templateName, in: context)
    let router = AIRouter()
    let result = try await router.summarize(transcript: recording.transcript, instructions: instructions)

    let summary = Summary(templateName: templateName, engineName: result.attribution, content: result.text)
    summary.recording = recording
    recording.summaries.append(summary)
    context.insert(summary)
    try? context.save()
    return result.text
}

@MainActor
private func templateInstructions(named name: String, in context: ModelContext) -> String {
    let all = (try? context.fetch(FetchDescriptor<SummaryTemplate>())) ?? []
    if let match = all.first(where: { $0.name == name }) { return match.instructions }
    // Fallback so intents work even before seeding.
    return BuiltInTemplates.all.first(where: { $0.name == name })?.instructions
        ?? "Summarize this transcript in a few clear bullet points."
}

struct SummarizeLastRecordingIntent: AppIntent {
    static let title: LocalizedStringResource = "Summarize my last recording"
    static let description = IntentDescription("Turns your most recent recording into notes using your selected AI.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = try await summarizeLatest(using: "Quick Summary")
        return .result(value: text, dialog: "Here's a summary of your last recording.")
    }
}

struct DraftFollowUpEmailIntent: AppIntent {
    static let title: LocalizedStringResource = "Draft a follow-up email from my last recording"
    static let description = IntentDescription("Drafts a follow-up email based on your most recent recording.")

    func perform() async throws -> some IntentResult & ReturnsValue<String> & ProvidesDialog {
        let text = try await summarizeLatest(using: "Follow-up Email")
        return .result(value: text, dialog: "I've drafted a follow-up email.")
    }
}

/// Exposes the intents to Shortcuts and Siri with spoken phrases.
struct MurmurShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: SummarizeLastRecordingIntent(),
            phrases: [
                "Summarize my last recording in \(.applicationName)",
                "Summarize my last \(.applicationName) recording",
            ],
            shortTitle: "Summarize last",
            systemImageName: "sparkles"
        )
        AppShortcut(
            intent: DraftFollowUpEmailIntent(),
            phrases: [
                "Draft a follow-up email in \(.applicationName)",
                "Write a follow-up from my last \(.applicationName) recording",
            ],
            shortTitle: "Follow-up email",
            systemImageName: "envelope"
        )
    }
}
