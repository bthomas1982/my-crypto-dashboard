import Foundation

/// The buyer's own OpenAI (or any OpenAI-compatible endpoint — OpenRouter,
/// a local server, Azure — by overriding `baseURL`). Same deal as Claude: their
/// key, their bill, straight from the phone. Included so Murmur is genuinely
/// AI-agnostic rather than locked to one vendor.
struct OpenAIEngine: SummarizationEngine {
    static let keyAccount = "openai.apiKey"
    static let modelDefault = "gpt-4o"

    let id = "openai"
    let displayName = "OpenAI / compatible (your key)"
    let requiresAPIKey = true

    var model: String
    var baseURL: URL

    init(model: String = OpenAIEngine.modelDefault,
         baseURL: URL = URL(string: "https://api.openai.com/v1")!) {
        self.model = model
        self.baseURL = baseURL
    }

    var attribution: String { "OpenAI (\(model))" }

    func availability() async -> EngineAvailability {
        KeychainStore.exists(Self.keyAccount) ? .ready : .needsAPIKey
    }

    func summarize(transcript: String, instructions: String) async throws -> String {
        guard !transcript.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SummarizationError.emptyTranscript
        }
        return try await complete(messages: [
            ("system", PromptBuilder.system),
            ("user", PromptBuilder.userMessage(instructions: instructions, transcript: transcript)),
        ])
    }

    func answer(question: String, transcript: String, history: [ChatMessage]) async throws -> String {
        var messages: [(String, String)] = [("system", PromptBuilder.askSystem(transcript: transcript))]
        messages += history.map { ($0.role.rawValue, $0.text) }
        messages.append(("user", question))
        return try await complete(messages: messages)
    }

    // MARK: - Chat Completions API

    private func complete(messages: [(role: String, content: String)]) async throws -> String {
        guard let apiKey = KeychainStore.get(Self.keyAccount), !apiKey.isEmpty else {
            throw SummarizationError.missingAPIKey
        }

        var request = URLRequest(url: baseURL.appendingPathComponent("chat/completions"))
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": model,
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

        // { "choices": [ { "message": { "content": "..." } } ] }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let text = message["content"] as? String, !text.isEmpty else {
            throw SummarizationError.decoding
        }
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
