import Foundation
import SwiftData

/// Orchestrates market data fetching with caching, rate limiting, and provider fallback.
///
/// Lookup order per call:
///   1. Fresh `CachedQuote` (age < 60 s) — returned immediately; no network.
///   2. Primary provider (Twelve Data) if rate-limiter allows.
///   3. Fallback provider (Finnhub) if rate-limiter allows and primary failed.
///   4. All failed → `MarketDataError.allProvidersFailed`.
///
/// Successful fetches upsert the cache.
///
/// NFT asset-type gating is the caller's responsibility: check
/// `AssetType.usesMarketQuote` before calling `fetchQuote(symbol:)`.
actor MarketDataService {

    private let modelContainer: ModelContainer
    private let providers: [any MarketDataProvider]
    private let rateLimiter: RateLimiter
    private let context: ModelContext

    init(
        modelContainer: ModelContainer,
        providers: [any MarketDataProvider],
        rateLimiter: RateLimiter = RateLimiter()
    ) {
        self.modelContainer = modelContainer
        self.providers = providers
        self.rateLimiter = rateLimiter
        self.context = ModelContext(modelContainer)
    }

    /// Convenience init for production wiring. Pulls Twelve Data as primary, Finnhub as fallback.
    init(
        modelContainer: ModelContainer,
        keychain: KeychainService,
        rateLimiter: RateLimiter = RateLimiter()
    ) {
        self.init(
            modelContainer: modelContainer,
            providers: [
                TwelveDataProvider(keychain: keychain),
                FinnhubProvider(keychain: keychain),
            ],
            rateLimiter: rateLimiter
        )
    }

    // MARK: - Public API

    /// Fetch a quote, honoring the cache and provider fallback chain.
    /// Callers must check `AssetType.usesMarketQuote` first for NFT gating.
    func fetchQuote(symbol rawSymbol: String) async throws -> QuoteResult {
        let symbol = Self.normalize(rawSymbol)

        if let cached = cachedRow(for: symbol), cached.isFresh {
            return cached.toResult()
        }

        var lastError: Error?
        for provider in providers {
            guard await rateLimiter.acquire(provider: provider.name) else {
                lastError = MarketDataError.rateLimitExceeded(provider: provider.name)
                continue
            }
            do {
                let result = try await provider.fetchQuote(symbol: symbol)
                upsert(result)
                return result
            } catch {
                lastError = error
                continue
            }
        }

        _ = lastError  // reserved for later observability — captured even if unused.
        throw MarketDataError.allProvidersFailed
    }

    /// Returns a snapshot of the cached quote, if any. Does not trigger a fetch.
    /// Returns a value-type `QuoteResult` so it can cross the actor boundary safely.
    func cachedQuote(for rawSymbol: String) -> QuoteResult? {
        cachedRow(for: Self.normalize(rawSymbol))?.toResult()
    }

    /// Most-recent cached fetch timestamp across all symbols served by a given provider.
    /// Used by `ProviderStatusView` to show "last successful fetch" without a live network call.
    func mostRecentFetch(by providerName: String) -> Date? {
        let descriptor = FetchDescriptor<CachedQuote>(
            predicate: #Predicate<CachedQuote> { $0.providerName == providerName },
            sortBy: [SortDescriptor(\.fetchedAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor).first)?.fetchedAt
    }

    // MARK: - Private

    private func cachedRow(for symbol: String) -> CachedQuote? {
        let descriptor = FetchDescriptor<CachedQuote>(
            predicate: #Predicate<CachedQuote> { $0.symbol == symbol }
        )
        return try? context.fetch(descriptor).first
    }

    private func upsert(_ result: QuoteResult) {
        let symbol = Self.normalize(result.symbol)
        if let existing = cachedRow(for: symbol) {
            existing.price         = result.price
            existing.change        = result.change
            existing.changePercent = result.changePercent
            existing.currency      = result.currency
            existing.providerName  = result.providerName
            existing.fetchedAt     = result.fetchedAt
        } else {
            context.insert(CachedQuote(
                symbol:        symbol,
                price:         result.price,
                change:        result.change,
                changePercent: result.changePercent,
                currency:      result.currency,
                providerName:  result.providerName,
                fetchedAt:     result.fetchedAt
            ))
        }
        try? context.save()
    }

    private static func normalize(_ symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
