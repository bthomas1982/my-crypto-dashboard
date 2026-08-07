import Foundation
import SwiftUI

/// Drives an "Ask your notes" conversation about one recording. Keeps the turns,
/// routes each question through whichever brain is selected, and grounds every
/// answer in the transcript.
@MainActor
@Observable
final class NotesConversation {
    var messages: [ChatMessage] = []
    var isThinking = false
    var errorMessage: String?

    private let transcript: String
    private let router: AIRouter

    init(transcript: String, router: AIRouter) {
        self.transcript = transcript
        self.router = router
    }

    /// Suggested opening questions to make the feature discoverable.
    static let starters = [
        "What were the decisions?",
        "List every action item and who owns it.",
        "Summarize this in three sentences.",
        "What did I commit to?",
    ]

    func ask(_ question: String) async {
        let trimmed = question.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isThinking else { return }

        let history = messages // turns before this question
        messages.append(ChatMessage(role: .user, text: trimmed))
        isThinking = true
        errorMessage = nil
        defer { isThinking = false }

        do {
            let answer = try await router.answer(question: trimmed, transcript: transcript, history: history)
            messages.append(ChatMessage(role: .assistant, text: answer))
        } catch {
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }
}
