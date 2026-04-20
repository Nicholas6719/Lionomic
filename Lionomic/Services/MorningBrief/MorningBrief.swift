import Foundation

/// In-memory value type describing a single morning brief. NOT persisted —
/// briefs are generated on demand from the current state of accounts,
/// profile, quotes, and recommendations.
struct MorningBrief: Hashable, Sendable {
    /// Multi-line human-readable summary shown on the dashboard card and
    /// used as the notification body (truncated).
    let narrativeSummary: String

    /// Optional line describing the day's net portfolio change. `nil` when
    /// no fresh quotes are available — keep the UI honest instead of
    /// reporting stale numbers.
    let portfolioChangeNote: String?

    /// Top 3 recommendations by confidence across all accounts.
    let topRecommendations: [Recommendation]

    /// When the brief was generated — drives the "Updated HH:mm" caption.
    let generatedAt: Date
}
