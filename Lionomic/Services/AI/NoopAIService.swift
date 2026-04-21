import Foundation

/// Fallback `AIService` used in tests and as a safety net. Never pretends
/// to be configured; always throws on `complete(...)`. Kept in the target
/// because `AIScaffoldTests` asserts its shape and because substituting
/// it into `AppEnvironment` is a one-line change when debugging.
final class NoopAIService: AIService {

    nonisolated init() {}

    nonisolated var isAvailable: Bool { false }

    nonisolated func complete(system: String, messages: [AIMessage]) async throws -> String {
        throw AIServiceError.notConfigured
    }

    nonisolated func complete(prompt: String) async throws -> String {
        throw AIServiceError.notConfigured
    }
}
