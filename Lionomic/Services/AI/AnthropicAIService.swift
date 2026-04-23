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
///
/// MContext: HTTP 429 and 5xx responses are retried with exponential
/// backoff + jitter (max 3 attempts — 1 original plus 2 retries). See
/// `withRetry` for the pure helper used by tests.
final class AnthropicAIService: AIService {

    // Hardcoded string constants — the model and API version are part
    // of the contract and should not drift silently.
    private let model: String = "claude-sonnet-4-5"
    private let maxTokens: Int = 1024
    private let anthropicVersion: String = "2023-06-01"
    private let endpoint: URL = URL(string: "https://api.anthropic.com/v1/messages")!

    // MARK: - Retry knobs

    /// Max attempts including the original. 1 original + 2 retries.
    static let retryMaxAttempts: Int = 3
    /// Initial delay before the first retry. Subsequent retries multiply
    /// this by `retryMultiplier`.
    static let retryBaseDelay: TimeInterval = 1.0
    static let retryMultiplier: Double = 2.0
    /// Random 0–0.5s added to each backoff to avoid thundering-herd.
    static let retryJitterRange: ClosedRange<Double> = 0.0...0.5

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

        // MContext: wrap the actual HTTP round-trip in `withRetry` so
        // transient 429/5xx responses auto-retry with backoff. Transport
        // failures and non-retryable HTTP statuses fall out immediately.
        return try await Self.withRetry(
            maxAttempts: Self.retryMaxAttempts,
            baseDelay: Self.retryBaseDelay,
            multiplier: Self.retryMultiplier
        ) {
            await Self.performSingleAttempt(request: request)
        }
    }

    nonisolated func complete(prompt: String) async throws -> String {
        try await complete(
            system: "",
            messages: [AIMessage(role: .user, content: prompt)]
        )
    }

    // MARK: - Single attempt
    //
    // Extracted so `withRetry` can drive repeated calls. Returns a
    // `RetryAttempt<String>` — the closure's own classification of
    // success/retryable/fatal — rather than throwing.

    private nonisolated static func performSingleAttempt(request: URLRequest) async -> RetryAttempt<String> {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await URLSession.shared.data(for: request)
        } catch {
            // Transport-level failures (no network, TLS, etc.) are
            // treated as fatal rather than retryable. 429/5xx are where
            // backoff actually helps; a DNS error won't be fixed by
            // waiting 2 seconds.
            return .fatal(AIServiceError.requestFailed("transport: \(error.localizedDescription)"))
        }

        guard let http = response as? HTTPURLResponse else {
            return .fatal(AIServiceError.requestFailed("non-HTTP response"))
        }

        if (200...299).contains(http.statusCode) {
            do {
                let envelope = try JSONDecoder().decode(ResponseEnvelope.self, from: data)
                guard let text = envelope.content.first?.text, !text.isEmpty else {
                    return .fatal(AIServiceError.requestFailed("empty response content"))
                }
                return .success(text)
            } catch {
                return .fatal(AIServiceError.requestFailed("decode: \(error.localizedDescription)"))
            }
        }

        let bodyText = String(data: data, encoding: .utf8) ?? "(no body)"
        let error = AIServiceError.requestFailed(
            "status \(http.statusCode): \(bodyText.prefix(200))"
        )
        if isRetryable(statusCode: http.statusCode) {
            return .retryable(error)
        }
        return .fatal(error)
    }

    // MARK: - Retry classification (pure)

    /// 429 and any 5xx are retryable; everything else fails immediately.
    /// Kept as a separate function so tests can assert classification
    /// without driving the loop.
    nonisolated static func isRetryable(statusCode: Int) -> Bool {
        statusCode == 429 || (500..<600).contains(statusCode)
    }

    /// Computes the backoff delay for a given attempt index. Attempt 1
    /// is the original call and never sleeps; attempt 2 waits
    /// `baseDelay + jitter`; attempt 3 waits `baseDelay * multiplier + jitter`;
    /// and so on. Pure — jitter is supplied as a value, not generated here.
    nonisolated static func backoffDelay(
        beforeAttempt attempt: Int,
        baseDelay: TimeInterval,
        multiplier: Double,
        jitter: TimeInterval
    ) -> TimeInterval {
        // `attempt == 1` is the first try (no sleep). `attempt == 2` is
        // the first retry → baseDelay. Each subsequent retry multiplies.
        let exponent = max(0, attempt - 2)
        return baseDelay * pow(multiplier, Double(exponent)) + jitter
    }

    // MARK: - withRetry helper (pure, testable)

    /// Classification of a single attempt. The operation decides which
    /// case it returns — the loop does not inspect error types, which
    /// keeps the helper reusable for any retryable I/O.
    nonisolated enum RetryAttempt<T> {
        case success(T)
        case retryable(Error)
        case fatal(Error)
    }

    /// Runs `operation` up to `maxAttempts` times with exponential
    /// backoff between retries. `.retryable` results sleep then retry
    /// (until exhausted). `.fatal` results throw immediately. On
    /// exhaustion, throws the last retryable error observed.
    ///
    /// `jitter` and `sleep` are injected so tests can eliminate
    /// wall-clock delays and randomness entirely. Production defaults
    /// use `Double.random(in: retryJitterRange)` and `Task.sleep`.
    nonisolated static func withRetry<T: Sendable>(
        maxAttempts: Int,
        baseDelay: TimeInterval,
        multiplier: Double = retryMultiplier,
        jitter: @Sendable () -> TimeInterval = { Double.random(in: retryJitterRange) },
        // Swift rejects `Self.defaultSleep` as a default argument value
        // on a generic static method ("covariant Self cannot be
        // referenced from a default argument expression"), so spell out
        // the concrete type name here. Semantically identical.
        sleep: @Sendable (TimeInterval) async -> Void = AnthropicAIService.defaultSleep,
        operation: @Sendable () async -> RetryAttempt<T>
    ) async throws -> T {
        var lastError: Error = AIServiceError.requestFailed("retry loop did not execute")
        for attempt in 1...max(1, maxAttempts) {
            switch await operation() {
            case .success(let value):
                return value
            case .retryable(let error):
                lastError = error
                if attempt < maxAttempts {
                    let delay = backoffDelay(
                        beforeAttempt: attempt + 1,
                        baseDelay: baseDelay,
                        multiplier: multiplier,
                        jitter: jitter()
                    )
                    await sleep(delay)
                }
            case .fatal(let error):
                throw error
            }
        }
        throw lastError
    }

    /// Default sleep implementation — plain `Task.sleep(nanoseconds:)`.
    /// Cooperative: a cancelled task drops through immediately.
    nonisolated static func defaultSleep(_ seconds: TimeInterval) async {
        try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
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
