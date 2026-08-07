import Foundation

/// The buyer's own Claude. They paste an Anthropic API key (from
/// console.anthropic.com — note this is pay-as-you-go and separate from a
/// Claude.ai Pro/Max chat subscription). Pennies per summary; the key stays in
/// their Keychain and requests go straight from their phone to Anthropic.
struct ClaudeEngine: SummarizationEngine {
    static let keyAccount = "anthropic.apiKey"
    static let modelDefault = "claude-sonnet-5"

    let id = "claude"
    let displayName = "Claude (your key)"
    let requiresAPIKey = true

    /// User-configurable model id, stored in Settings.
    var model: String

    init(model: String = ClaudeEngine.modelDefault) { self.model = model }

    var attribution: String { "Claude (\(model))" }

    func availability() async -> EngineAvailability {
        KeychainStore.exists(Self.keyAccount) ? .ready : .needsAPIKey
    }

    func summarize(transcript: String, instructions: String) async throws -> String {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.emptyTranscript
        }
        return try await complete(
            system: PromptBuilder.system,
            messages: [("user", PromptBuilder.userMessage(instructions: instructions, transcript: transcript))]
        )
    }

    func answer(question: String, transcript: String, history: [ChatMessage]) async throws -> String {
        var messages: [(String, String)] = history.map { ($0.role.rawValue, $0.text) }
        messages.append(("user", question))
        return try await complete(system: PromptBuilder.askSystem(transcript: transcript), messages: messages)
    }

    // MARK: - Anthropic Messages API

    private func complete(system: String, messages: [(role: String, content: String)]) async throws -> String {
        guard let apiKey = KeychainStore.get(Self.keyAccount), !apiKey.isEmpty else {
            throw SummarizationError.missingAPIKey
        }

        var request = URLRequest(url: URL(string: "https://api.anthropic.com/v1/messages")!)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "system": system,
            "messages": messages.map { ["role": $0.role, "content": $0.content] },
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response): (Data, URLResponse)
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw SummarizationError.transport(error.localizedDescription)
        }

        guard let http = response as? HTTPURLResponse else { throw SummarizationError.decoding }
        guard (200..<300).contains(http.statusCode) else {
            throw SummarizationError.http(status: http.statusCode, message: Self.apiError(data))
        }

        // { "content": [ { "type": "text", "text": "..." } ] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            throw SummarizationError.decoding
        }
        let text = content.compactMap { $0["text"] as? String }.joined()
        guard !text.isEmpty else { throw SummarizationError.decoding }
        return text
    }

    private static func apiError(_ data: Data) -> String {
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            return message
        }
        return String(data: data, encoding: .utf8) ?? "Unknown error"
    }
}
