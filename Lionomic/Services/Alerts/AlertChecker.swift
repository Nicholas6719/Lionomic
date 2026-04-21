import Foundation

/// Pure threshold-crossing checker. No I/O, no dependencies. Safe to call
/// from any actor. Used by `AlertFiringCoordinator` on both the Holding
/// side (fires `.priceAlert`) and the WatchlistItem side (fires
/// `.watchlistAlert`) — the AlertKind is context-dependent and supplied
/// by the coordinator, while the direction is what this function computes.
struct AlertChecker {

    /// Which threshold was crossed in this update.
    enum Direction: String, Sendable, Equatable, Hashable {
        case above
        case below
    }

    /// Returns the direction that was crossed between `previousPrice` and
    /// `newPrice`, or nil if neither threshold was crossed.
    ///
    /// Rules:
    /// - `previousPrice == nil` (first quote fetch) → always nil. We need
    ///   a direction to evaluate, and a first fetch has no "before".
    /// - `alertAbove`: crossed when `previousPrice < alertAbove` and
    ///   `newPrice >= alertAbove`.
    /// - `alertBelow`: crossed when `previousPrice > alertBelow` and
    ///   `newPrice <= alertBelow`.
    /// - If both crossed in a single update (edge case possible on
    ///   degenerate thresholds with `alertBelow > alertAbove`), the above
    ///   crossing wins — kept consistent with the spec's tiebreaker.
    static func checkCrossing(
        previousPrice: Decimal?,
        newPrice: Decimal,
        alertAbove: Decimal?,
        alertBelow: Decimal?
    ) -> Direction? {
        guard let previousPrice else { return nil }

        let crossedAbove: Bool
        if let alertAbove {
            crossedAbove = previousPrice < alertAbove && newPrice >= alertAbove
        } else {
            crossedAbove = false
        }

        if crossedAbove { return .above }

        if let alertBelow,
           previousPrice > alertBelow && newPrice <= alertBelow {
            return .below
        }

        return nil
    }
}
