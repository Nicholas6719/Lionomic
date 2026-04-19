import Testing
import Foundation
import SwiftData
@testable import Lionomic

// MARK: - Mock provider

/// An in-memory provider that returns a fixed quote or an injected error.
/// Tracks call count and the symbols it was asked about.
actor MockProvider: MarketDataProvider {
    nonisolated let name: String
    private let scriptedResponse: Result<QuoteResult, MarketDataError>

    private var _callCount: Int = 0
    private var _askedSymbols: [String] = []

    init(name: String, response: Result<QuoteResult, MarketDataError>) {
        self.name = name
        self.scriptedResponse = response
    }

    var callCount: Int { _callCount }
    var askedSymbols: [String] { _askedSymbols }

    nonisolated func fetchQuote(symbol: String) async throws -> QuoteResult {
        await record(symbol)
        switch scriptedResponse {
        case .success(let quote):
            return QuoteResult(
                symbol: symbol,
                price: quote.price,
                change: quote.change,
                changePercent: quote.changePercent,
                currency: quote.currency,
                fetchedAt: Date(),
                providerName: name
            )
        case .failure(let error):
            throw error
        }
    }

    private func record(_ symbol: String) {
        _callCount += 1
        _askedSymbols.append(symbol)
    }
}

private func fixedQuote(symbol: String, price: Decimal, provider: String) -> QuoteResult {
    QuoteResult(
        symbol: symbol,
        price: price,
        change: 0,
        changePercent: 0,
        currency: "USD",
        fetchedAt: Date(),
        providerName: provider
    )
}

// MARK: - Tests

struct MarketDataServiceTests {

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    }

    /// Permissive rate limiter — 0 s gap means every call is allowed.
    private let openGaps: [String: TimeInterval] = ["Primary": 0, "Fallback": 0]

    @Test("A fresh cache miss triggers a provider fetch")
    func cacheMissTriggersFetch() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .success(fixedQuote(symbol: "AAPL", price: 100, provider: "Primary"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        let result = try await service.fetchQuote(symbol: "AAPL")

        #expect(result.price == 100)
        #expect(result.providerName == "Primary")
        let calls = await primary.callCount
        #expect(calls == 1)
    }

    @Test("A cache hit within 60 s returns cached data without fetching")
    func cacheHitSkipsFetch() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .success(fixedQuote(symbol: "AAPL", price: 100, provider: "Primary"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        // First call populates cache
        _ = try await service.fetchQuote(symbol: "AAPL")
        // Second call should read cache
        _ = try await service.fetchQuote(symbol: "AAPL")

        let calls = await primary.callCount
        #expect(calls == 1)
    }

    @Test("A stale cache entry (>60 s old) triggers a new fetch")
    func staleCacheTriggersFetch() async throws {
        let container = try makeContainer()

        // Pre-seed a stale CachedQuote (fetchedAt 120 s in the past)
        let context = ModelContext(container)
        context.insert(CachedQuote(
            symbol:        "AAPL",
            price:         50,
            change:        0,
            changePercent: 0,
            currency:      "USD",
            providerName:  "Primary",
            fetchedAt:     Date().addingTimeInterval(-120)
        ))
        try context.save()

        let primary = MockProvider(
            name: "Primary",
            response: .success(fixedQuote(symbol: "AAPL", price: 100, provider: "Primary"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        let result = try await service.fetchQuote(symbol: "AAPL")
        // Should have fetched fresh, not returned the stale 50
        #expect(result.price == 100)
        let calls = await primary.callCount
        #expect(calls == 1)
    }

    @Test("If primary throws, fallback is tried")
    func fallbackAfterPrimaryFails() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .failure(.missingAPIKey(provider: "Primary"))
        )
        let fallback = MockProvider(
            name: "Fallback",
            response: .success(fixedQuote(symbol: "MSFT", price: 350, provider: "Fallback"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary, fallback],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        let result = try await service.fetchQuote(symbol: "MSFT")
        #expect(result.price == 350)
        #expect(result.providerName == "Fallback")
        let primaryCalls = await primary.callCount
        let fallbackCalls = await fallback.callCount
        #expect(primaryCalls == 1)
        #expect(fallbackCalls == 1)
    }

    @Test("If both providers throw, allProvidersFailed is thrown")
    func allFailed() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .failure(.missingAPIKey(provider: "Primary"))
        )
        let fallback = MockProvider(
            name: "Fallback",
            response: .failure(.missingAPIKey(provider: "Fallback"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary, fallback],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        await #expect(throws: MarketDataError.allProvidersFailed) {
            _ = try await service.fetchQuote(symbol: "AAPL")
        }
    }

    @Test("NFT symbols are never fetched (caller checks usesMarketQuote)")
    func nftSymbolsNotFetched() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .success(fixedQuote(symbol: "NFT", price: 1, provider: "Primary"))
        )
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary],
            rateLimiter: RateLimiter(gaps: openGaps)
        )

        // Simulate the caller's gate: only call fetchQuote if the asset type
        // uses market quotes. NFT does not → no fetch should occur.
        let nftAsset = AssetType.nft
        if nftAsset.usesMarketQuote {
            _ = try await service.fetchQuote(symbol: "PUNK-1")
        }

        let calls = await primary.callCount
        #expect(calls == 0)
    }

    @Test("A rate-limited primary still allows fallback to succeed")
    func rateLimitedPrimaryFallsBack() async throws {
        let container = try makeContainer()
        let primary = MockProvider(
            name: "Primary",
            response: .success(fixedQuote(symbol: "AAPL", price: 100, provider: "Primary"))
        )
        let fallback = MockProvider(
            name: "Fallback",
            response: .success(fixedQuote(symbol: "AAPL", price: 101, provider: "Fallback"))
        )

        // First call: primary wins.
        let service = MarketDataService(
            modelContainer: container,
            providers: [primary, fallback],
            rateLimiter: RateLimiter(gaps: ["Primary": 60, "Fallback": 0])
        )
        _ = try await service.fetchQuote(symbol: "AAPL")

        // Poison the cache so the second call must hit a provider.
        // Rate limiter blocks Primary; Fallback takes over.
        let context = ModelContext(container)
        let quotes = try context.fetch(FetchDescriptor<CachedQuote>())
        if let cached = quotes.first {
            cached.fetchedAt = Date().addingTimeInterval(-120)
            try context.save()
        }

        let result = try await service.fetchQuote(symbol: "AAPL")
        #expect(result.providerName == "Fallback")
    }
}
