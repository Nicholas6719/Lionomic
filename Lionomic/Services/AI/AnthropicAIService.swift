import Foundation

/// Anthropic-backed `AIService`. Makes real HTTP calls to the Messages API.
///
/// Two initializers:
///   - `init(keychainService:)` — production path. The API key is loaded
///     from Keychain on every call, so a key entered during the session
///     is picked up without restart.
///   - `init(apiKey:)` — convenience for tests and previews.
///
/// All methods are `nonisolated` so the service can be called from any
/// actor, consistent with `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`.
final class AnthropicAIService: AIService {

    // Hardcoded string constants — the model and API version are part
    // of the contract and should not drift silently.
    private let model: String = "claude-sonnet-4-5"
    private let maxTokens: Int = 1024
    private let anthropicVersion: String = "2023-06-01"
    private let endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!

    private let keychainService: KeychainService?
    private let staticApiKey: String?

    /// Production init — pulls the key from Keychain lazily on each call
    /// so that a key entered mid-session takes effect immediately.
    nonisolated init(keychainService: KeychainService) {
        self.keychainService = keychainService
        self.staticApiKey = nil
    }

    /// Test/preview init — pins a specific key (or empty string to
    /// simulate "no key saved").
    nonisolated init(apiKey: String) {
        self.keychainService = nil
        self.staticApiKey = apiKey
    }

    /// Key-reading path. Marked `nonisolated` because both `isAvailable`
    /// and `complete(system:messages:)` are `nonisolated` and need to
    /// read it. Under `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` a
    /// computed property without an explicit isolation annotation
    /// defaults to MainActor, which Swift 6 mode rejects when called
    /// from a nonisolated context. Every dependency it touches
    /// (`staticApiKey` / `keychainService.load`) is Sendable + nonisolated.
    private nonisolated var currentKey: String {
        if let staticApiKey { return staticApiKey }
        return keychainService?.load(identifier: KeychainService.anthropicApiKeyIdentifier) ?? ""
    }

    nonisolated var isAvailable: Bool {
        !currentKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    nonisolated func complete(system: String, messages: [AIMessage]) async throws -> String {
        let key = currentKey.trimmingCharacters(in: .whitespaces)
        guard !key.isEmpty else {
            throw AIServiceError.notConfigured
        }
        guard !messages.isEmpty else {
            throw AIServiceError.requestFailed("no messages to send")
        }

        let body = RequestBody(
            model: model,
            max_tokens: maxTokens,
            system: system.isEmpty ? nil : system,
            messages: messages.map { RequestMessage(role: $0.role.rawValue, content: $0.content) }
        )

        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "x-api-key")
        request.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")

        do {
            request.httpBody = try JSONEncoder().encode(body)
        } catch {
            throw AIServiceError.requestFailed("encode: \(error.localizedDescription)")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            throw AIServiceError.requestFailed("transport: \(error.localizedDescription)")
        }

        guard let http = response as? HTTPURLResponse else {
            throw AIServiceError.requestFailed("non-HTTP response")
        }
        guard (200...299).contains(http.statusCode) else {
            let bodyText = String(data: data, encoding: .utf8) ?? "(no body)"
            throw AIServiceError.requestFailed(
                "status \(http.statusCode): \(bodyText.prefix(200))"
            )
        }

        let envelope: ResponseEnvelope
        do {
            envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
        } catch {
            throw AIServiceError.requestFailed("decode: \(error.localizedDescription)")
        }

        guard let text = envelope.content.first?.text, !text.isEmpty else {
            throw AIServiceError.requestFailed("empty response content")
        }
        return text
    }

    nonisolated func complete(prompt: String) async throws -> String {
        try await complete(
            system: "",
            messages: [AIMessage(role: .user, content: prompt)]
        )
    }

    // MARK: - Wire types
    //
    // Every nested struct is `nonisolated` because they are constructed,
    // encoded, and decoded from inside `complete(system:messages:)`,
    // which is `nonisolated`. Without the annotation they inherit
    // MainActor isolation from the project-wide default, making their
    // `Encodable` / `Decodable` conformances MainActor-isolated — Swift 6
    // rejects using those conformances from non-MainActor contexts.

    private nonisolated struct RequestBody: Encodable {
        let model: String
        let max_tokens: Int
        let system: String?
        let messages: [RequestMessage]
    }

    private nonisolated struct RequestMessage: Encodable {
        let role: String
        let content: String
    }

    private nonisolated struct ResponseEnvelope: Decodable {
        let content: [ContentBlock]
    }

    private nonisolated struct ContentBlock: Decodable {
        let type: String
        let text: String
    }
}
