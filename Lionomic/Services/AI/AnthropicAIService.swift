import Foundation

/// Stub implementation of `AIService` that will eventually call the
/// Anthropic API. In M10 it is **not** wired into `AppEnvironment` —
/// the environment uses `NoopAIService`. This class exists only to
/// prove the wiring shape and to hold the Keychain-backed key slot.
///
/// `isAvailable` mirrors the key's non-empty state so the future Chat
/// feature can gate its UI on "key present." `complete(prompt:)` throws
/// `.notConfigured` unconditionally until the real network call lands.
final class AnthropicAIService: AIService {

    private let apiKey: String

    nonisolated init(apiKey: String) {
        self.apiKey = apiKey
    }

    nonisolated var isAvailable: Bool { !apiKey.isEmpty }

    // TODO: M10+ — implement Anthropic API call.
    //
    // Rough shape when we get there:
    //   POST https://api.anthropic.com/v1/messages
    //   headers: x-api-key, anthropic-version, content-type: application/json
    //   body: { model, max_tokens, messages: [{role:"user", content: prompt}] }
    //   Parse `content[0].text` from the response envelope.
    //
    // Until then: keep this throwing so accidental invocation in V1 is
    // loud, not silently returning a fake completion.
    nonisolated func complete(prompt: String) async throws -> String {
        throw AIServiceError.notConfigured
    }
}
