import Foundation

/// Default `AIService` wired into `AppEnvironment` in V1. Never pretends
/// to be configured; always throws on `complete(prompt:)`. Keeps the
/// wiring proof testable without requiring a live API key, and lets us
/// ship the scaffold without any network code.
///
/// The swap to a real `AnthropicAIService` happens in `AppEnvironment`
/// when that implementation is ready — nowhere else in the app needs to
/// change.
final class NoopAIService: AIService {

    nonisolated init() {}

    nonisolated var isAvailable: Bool { false }

    nonisolated func complete(prompt: String) async throws -> String {
        throw AIServiceError.notConfigured
    }
}
