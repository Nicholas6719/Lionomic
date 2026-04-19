import Foundation

/// Per-provider minimum-gap enforcement.
///
/// Tracks the last request time per provider and refuses new calls that would
/// violate the configured gap. Calls are refused with a `Bool` return value —
/// callers (usually `MarketDataService`) treat that as a `.rateLimitExceeded`
/// and fall through to the next provider.
///
/// Conservative defaults respect the free plans:
///   - Twelve Data: 12 s (free plan allows 8 calls/min)
///   - Finnhub:      2 s (free plan allows 60 calls/min)
actor RateLimiter {

    static let defaultGaps: [String: TimeInterval] = [
        "Twelve Data": 12,
        "Finnhub":      2,
    ]

    private var gaps: [String: TimeInterval]
    private var lastRequestByProvider: [String: Date] = [:]

    init(gaps: [String: TimeInterval] = defaultGaps) {
        self.gaps = gaps
    }

    /// Atomically check + stamp. Returns `true` if a request is allowed.
    /// Returns `false` (and does NOT update the timestamp) if the request would
    /// fall inside the configured gap.
    @discardableResult
    func acquire(provider: String) -> Bool {
        let gap = gaps[provider] ?? 0
        let now = Date()
        if let last = lastRequestByProvider[provider],
           now.timeIntervalSince(last) < gap {
            return false
        }
        lastRequestByProvider[provider] = now
        return true
    }

    /// The interval (in seconds) the caller must wait before the next call to
    /// this provider would be accepted. Zero when no wait is required.
    func timeUntilNextAllowed(provider: String) -> TimeInterval {
        let gap = gaps[provider] ?? 0
        guard let last = lastRequestByProvider[provider] else { return 0 }
        return max(0, gap - Date().timeIntervalSince(last))
    }
}
