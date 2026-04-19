import Foundation

/// Value-type snapshot of a market data quote.
/// Returned by `MarketDataProvider.fetchQuote` and `MarketDataService.fetchQuote`.
/// Crossing actor boundaries requires Sendable — all stored properties are value types.
struct QuoteResult: Hashable, Sendable {
    let symbol: String
    let price: Decimal
    let change: Decimal
    let changePercent: Decimal
    let currency: String
    let fetchedAt: Date
    let providerName: String

    /// Explicit `nonisolated` initializer. The module defaults to MainActor
    /// (`SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`); without this, `QuoteResult.init`
    /// would be MainActor-isolated and could not be called from the `MarketDataService`
    /// actor or from `nonisolated` provider code.
    nonisolated init(
        symbol: String,
        price: Decimal,
        change: Decimal,
        changePercent: Decimal,
        currency: String,
        fetchedAt: Date,
        providerName: String
    ) {
        self.symbol = symbol
        self.price = price
        self.change = change
        self.changePercent = changePercent
        self.currency = currency
        self.fetchedAt = fetchedAt
        self.providerName = providerName
    }

    /// Age of the quote relative to now.
    nonisolated var age: TimeInterval { Date().timeIntervalSince(fetchedAt) }

    /// A quote is "fresh" for 60 seconds, per the M4 cache policy.
    nonisolated static let freshnessWindow: TimeInterval = 60

    nonisolated var isFresh: Bool { age < Self.freshnessWindow }
}
