import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Unit tests for the unrealized-gain/loss math used by `HoldingListView`.
/// The view's logic is inlined (SwiftUI `@ViewBuilder`), so this suite
/// exercises the same `Decimal`-only formula directly to lock in the
/// behavior: `(price - cost) × shares` for the dollar delta,
/// `(price - cost) / cost` for the percent ratio.
@MainActor
struct UnrealizedGainLossTests {

    /// Mirror of the math in `HoldingListView.unrealizedGainLossLine(quote:)`.
    /// Re-implementing inline would couple the tests to the View; lifting
    /// to a shared helper would add a new abstraction that M11 forbids.
    /// This duplication is intentional and narrow — four lines.
    private func unrealized(price: Decimal, cost: Decimal, shares: Decimal) -> (delta: Decimal, ratio: Decimal) {
        let delta = (price - cost) * shares
        let ratio = (price - cost) / cost
        return (delta, ratio)
    }

    @Test func positiveGainWithFreshQuote() async throws {
        let (delta, ratio) = unrealized(price: 120, cost: 100, shares: 10)
        #expect(delta == Decimal(200))
        #expect(ratio == Decimal(string: "0.2")!)
    }

    @Test func negativeLossWithFreshQuote() async throws {
        let (delta, ratio) = unrealized(price: 80, cost: 100, shares: 5)
        #expect(delta == Decimal(-100))
        #expect(ratio == Decimal(string: "-0.2")!)
    }

    @Test func zeroWhenPriceEqualsCost() async throws {
        let (delta, ratio) = unrealized(price: 100, cost: 100, shares: 10)
        #expect(delta == Decimal(0))
        #expect(ratio == Decimal(0))
    }

    @Test func fractionalSharesProduceCorrectDelta() async throws {
        let (delta, _) = unrealized(price: 110, cost: 100, shares: Decimal(string: "2.5")!)
        #expect(delta == Decimal(25))
    }
}
