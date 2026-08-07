import Foundation
import FoundationModels

/// The default brain: Apple's on-device model (iOS 26 Foundation Models).
/// Free, private, offline, no API key. This is what makes Murmur work for every
/// buyer the moment they install it — the "no subscription" floor.
///
/// Trade-off: it's a ~3B model. Excellent at cleanup, extraction, and short
/// structured summaries; the buyer's own Claude/OpenAI key is the upgrade for
/// long transcripts and richer reasoning.
struct AppleFoundationEngine: SummarizationEngine {
    let id = "apple"
    let displayName = "Apple (on-device)"
    let attribution = "Apple on-device"
    let requiresAPIKey = false

    func availability() async -> EngineAvailability {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(let reason):
            return .unavailable(reason: Self.describe(reason))
        }
    }

    func summarize(transcript: String, instructions: String) async throws -> String {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.emptyTranscript
        }
        guard case .available = SystemLanguageModel.default.availability else {
            throw SummarizationError.modelUnavailable("Apple Intelligence is off or unsupported on this device.")
        }

        let session = LanguageModelSession(instructions: PromptBuilder.system)
        let prompt = PromptBuilder.userMessage(instructions: instructions, transcript: transcript)
        let response = try await session.respond(to: prompt)
        return response.content
    }

    func answer(question: String, transcript: String, history: [ChatMessage]) async throws -> String {
        guard case .available = SystemLanguageModel.default.availability else {
            throw SummarizationError.modelUnavailable("Apple Intelligence is off or unsupported on this device.")
        }
        // The on-device session is single-shot here; we fold prior turns into the
        // prompt so context is preserved without holding a live session.
        let session = LanguageModelSession(instructions: PromptBuilder.askSystem(transcript: transcript))
        let priorTurns = history.map { turn in
            "\(turn.role == .user ? "User" : "Assistant"): \(turn.text)"
        }.joined(separator: "\n")
        let prompt = priorTurns.isEmpty ? question : "\(priorTurns)\nUser: \(question)"
        let response = try await session.respond(to: prompt)
        return response.content
    }

    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:      return "This device doesn't support Apple Intelligence."
        case .appleIntelligenceNotEnabled: return "Turn on Apple Intelligence in Settings to use the on-device model."
        case .modelNotReady:          return "The on-device model is still downloading. Try again shortly."
        @unknown default:             return "The on-device model isn't available right now."
        }
    }
}
