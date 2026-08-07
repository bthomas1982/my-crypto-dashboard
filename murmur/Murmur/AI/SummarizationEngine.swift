import Foundation

/// The one abstraction every "brain" implements. Adding a provider = writing one
/// of these. The rest of the app never knows which brain answered — it just asks
/// for a summary. This is what makes Murmur AI-agnostic: on-device today, the
/// buyer's own Claude/OpenAI key tomorrow, anything Apple's LanguageModel
/// protocol exposes in future.
protocol SummarizationEngine: Sendable {
    /// Stable identifier used in settings, e.g. "apple".
    var id: String { get }
    /// Shown in the UI, e.g. "Apple (on-device)".
    var displayName: String { get }
    /// Recorded against each Summary so the user can see what produced it.
    var attribution: String { get }
    /// True if this brain needs the user to supply an API key.
    var requiresAPIKey: Bool { get }

    /// Whether this brain can run right now (model available / key present).
    func availability() async -> EngineAvailability

    /// Turn a transcript into a summary using the template's instructions.
    func summarize(transcript: String, instructions: String) async throws -> String
}

enum EngineAvailability: Equatable {
    case ready
    case needsAPIKey
    case unavailable(reason: String)

    var isReady: Bool { self == .ready }
}

enum SummarizationError: LocalizedError {
    case emptyTranscript
    case missingAPIKey
    case modelUnavailable(String)
    case http(status: Int, message: String)
    case decoding
    case transport(String)

    var errorDescription: String? {
        switch self {
        case .emptyTranscript:      return "There's no transcript to summarize yet."
        case .missingAPIKey:        return "Add your API key in Settings to use this AI provider."
        case .modelUnavailable(let s): return "The on-device model isn't available: \(s)"
        case .http(let status, let message):
            return "The AI provider returned an error (\(status)): \(message)"
        case .decoding:             return "Couldn't read the AI provider's response."
        case .transport(let s):     return "Network problem reaching the AI provider: \(s)"
        }
    }
}

/// Shared helper: assemble the final prompt sent to any text model.
enum PromptBuilder {
    static func userMessage(instructions: String, transcript: String) -> String {
        """
        \(instructions)

        ---
        Here is the transcript to work from:

        \(transcript)
        """
    }

    static let system = """
    You transform raw meeting and voice-note transcripts into clean, useful notes. \
    The transcript is machine-generated and may contain errors — use judgement, but \
    never invent facts, names, numbers, or decisions that aren't supported by the text. \
    Respond in Markdown. Do not add meta-commentary about being an AI.
    """
}
