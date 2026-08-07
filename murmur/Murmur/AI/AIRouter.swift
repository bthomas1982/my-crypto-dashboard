import Foundation
import SwiftUI

/// Holds the user's AI preferences and hands back the right engine. This is the
/// single place the rest of the app asks "which brain?" — swap providers here
/// and every summary follows. Backed by @AppObservable settings persisted in
/// UserDefaults (keys themselves live in the Keychain, not here).
@MainActor
@Observable
final class AIRouter {
    enum Provider: String, CaseIterable, Identifiable {
        case apple, claude, openai
        var id: String { rawValue }
        var label: String {
            switch self {
            case .apple:  return "Apple (on-device)"
            case .claude: return "Claude"
            case .openai: return "OpenAI / compatible"
            }
        }
        var blurb: String {
            switch self {
            case .apple:  return "Free, private, works offline. No key needed. Best for cleanup and short notes."
            case .claude: return "Your Anthropic API key. Best quality for long, complex transcripts."
            case .openai: return "Your OpenAI (or compatible) key. Works with OpenRouter, Azure, local servers."
            }
        }
    }

    // Persisted lightweight preferences.
    var provider: Provider {
        didSet { defaults.set(provider.rawValue, forKey: "ai.provider") }
    }
    var claudeModel: String {
        didSet { defaults.set(claudeModel, forKey: "ai.claudeModel") }
    }
    var openAIModel: String {
        didSet { defaults.set(openAIModel, forKey: "ai.openAIModel") }
    }

    private let defaults = UserDefaults.standard

    init() {
        provider = Provider(rawValue: defaults.string(forKey: "ai.provider") ?? "") ?? .apple
        claudeModel = defaults.string(forKey: "ai.claudeModel") ?? ClaudeEngine.modelDefault
        openAIModel = defaults.string(forKey: "ai.openAIModel") ?? OpenAIEngine.modelDefault
    }

    /// The engine for the currently-selected provider.
    var engine: SummarizationEngine {
        switch provider {
        case .apple:  return AppleFoundationEngine()
        case .claude: return ClaudeEngine(model: claudeModel)
        case .openai: return OpenAIEngine(model: openAIModel)
        }
    }

    func summarize(transcript: String, instructions: String) async throws -> (text: String, attribution: String) {
        let engine = engine
        let text = try await engine.summarize(transcript: transcript, instructions: instructions)
        return (text, engine.attribution)
    }

    func availability() async -> EngineAvailability { await engine.availability() }
}
