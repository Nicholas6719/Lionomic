import Foundation

/// A single message exchanged with an AI service. The wire type that
/// flows between `ChatViewModel` and any `AIService` conformance; kept
/// separate from the UI-facing `ChatMessage` to avoid coupling the
/// service layer to the chat feature's model type.
struct AIMessage: Sendable, Equatable, Hashable {
    enum Role: String, Sendable, Equatable, Hashable {
        case user
        case assistant
    }
    let role: Role
    let content: String

    init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

/// Protocol for an AI completion service. In V1 only two conformances
/// exist (`NoopAIService` and `AnthropicAIService`); both are long-lived
/// reference types owned by `AppEnvironment`, hence the `AnyObject` bound.
///
/// Two entry points:
///   - `complete(system:messages:)` — the full multi-turn path used by
///     `ChatViewModel`. System prompt may be empty.
///   - `complete(prompt:)` — single-turn convenience. Default
///     implementation wraps the multi-turn path with a single user
///     message and empty system prompt.
protocol AIService: AnyObject {
    /// `true` once the service has everything it needs to make a call
    /// (in practice: the Anthropic key is present and non-empty).
    var isAvailable: Bool { get }

    /// Primary multi-turn entry point. `system` may be empty.
    func complete(system: String, messages: [AIMessage]) async throws -> String

    /// Convenience for single-turn callers that don't need history.
    func complete(prompt: String) async throws -> String
}

extension AIService {
    /// Default single-turn implementation routes through the multi-turn
    /// API with an empty system prompt and one user message.
    func complete(prompt: String) async throws -> String {
        try await complete(
            system: "",
            messages: [AIMessage(role: .user, content: prompt)]
        )
    }
}

/// Errors surfaced by any `AIService`. Kept minimal — the Chat UI surfaces
/// these directly to the user via a small banner.
enum AIServiceError: Error, Equatable {
    /// The service cannot fulfill a request — typically because no key
    /// is saved in Keychain, or an explicit empty-key stub was used.
    case notConfigured

    /// A configured request failed at runtime (non-2xx status, decode
    /// failure, transport error). The associated string is a short,
    /// human-readable reason suitable for logging and user display.
    case requestFailed(String)
}
