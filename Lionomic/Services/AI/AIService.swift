import Foundation

/// Scaffold protocol for an AI completion service. Kept deliberately
/// narrow in V1 — only the two methods needed by the future Chat feature
/// (flag-gated) and by any prompt-driven UX that follows.
///
/// Conformances:
///   - `NoopAIService` — shipped default. `isAvailable == false`.
///   - `AnthropicAIService` — stub. Throws `.notConfigured` in V1;
///      concrete HTTP implementation arrives in a later milestone.
///
/// The protocol is `AnyObject`-bound because conformers are long-lived
/// reference types owned by `AppEnvironment`. Values don't flow across
/// actor boundaries here, so no `Sendable` requirement — `@MainActor`
/// conformers satisfy call sites that need it.
protocol AIService: AnyObject {
    /// `true` once the service has everything it needs to make a call
    /// (in practice: the Anthropic key is present and non-empty).
    /// Callers that need to show "Chat requires a key" UI should read
    /// this, not inspect Keychain directly.
    var isAvailable: Bool { get }

    /// Complete a prompt. V1 implementations either return a completion
    /// string or throw. No streaming API in the scaffold.
    func complete(prompt: String) async throws -> String
}

/// Errors surfaced by any `AIService`. Kept minimal — the scaffold
/// doesn't model network/auth failures yet; those arrive with the real
/// Anthropic implementation.
enum AIServiceError: Error, Equatable {
    /// The service cannot fulfill a request — either no key, the feature
    /// is behind a flag, or the V1 stub has no backing implementation.
    case notConfigured

    /// A configured request failed at runtime. The associated string is
    /// a short, human-readable reason suitable for logging.
    case requestFailed(String)
}
