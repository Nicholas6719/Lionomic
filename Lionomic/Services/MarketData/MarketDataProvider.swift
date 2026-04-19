import Foundation

/// A single market data provider (Twelve Data, Finnhub, etc.).
/// Providers read their API key from Keychain at fetch time — never at init.
/// Conforming types must be `Sendable` so they can be held inside an `actor`.
///
/// All requirements are `nonisolated` so the orchestrating `MarketDataService`
/// actor can use them without actor hops.
protocol MarketDataProvider: Sendable {
    /// Stable display name used in error messages, the rate limiter, and `QuoteResult.providerName`.
    nonisolated var name: String { get }

    nonisolated func fetchQuote(symbol: String) async throws -> QuoteResult
}
