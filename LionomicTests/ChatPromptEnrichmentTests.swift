import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// MContext: verifies that the enriched system prompt contains live
/// cached prices and per-account override rows when they exist, and
/// omits the Current Market Prices / Account Overrides sections when
/// nothing qualifies. Tests build SwiftData fixtures in an in-memory
/// container and exercise `ChatViewModel.buildSystemPrompt()` end-to-end
/// so the actor hop into MarketDataService is also exercised.
@MainActor
struct ChatPromptEnrichmentTests {

    private struct Bundle {
        let vm: ChatViewModel
        let mock: MockAIService
        let profile: ProfileRepository
        let portfolio: PortfolioRepository
        let watchlist: WatchlistRepository
        let market: MarketDataService
        let context: ModelContext
        let container: ModelContainer
    }

    private func makeBundle() throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let profile = ProfileRepository(modelContext: context)
        _ = try profile.commit(draft: DraftProfile())
        let portfolio = PortfolioRepository(
            modelContext: context,
            profileRepository: profile
        )
        let watchlist = WatchlistRepository(modelContext: context)
        try watchlist.seedDefaultsIfNeeded()
        let market = MarketDataService(modelContainer: container, providers: [])
        let mock = MockAIService(response: .success("ok"))
        let vm = ChatViewModel(
            aiService: mock,
            profileRepository: profile,
            portfolioRepository: portfolio,
            watchlistRepository: watchlist,
            marketDataService: market
        )
        return Bundle(
            vm: vm, mock: mock,
            profile: profile, portfolio: portfolio,
            watchlist: watchlist, market: market,
            context: context, container: container
        )
    }

    /// Helper: seed CachedQuote directly (the MarketDataService test
    /// init has no providers, so `fetchQuote` would fail — but
    /// `cachedQuote(for:)` reads whatever is in the store). Uses the
    /// same container so the actor's internal ModelContext sees it.
    private func insertCachedQuote(
        _ context: ModelContext,
        symbol: String,
        price: Decimal
    ) throws {
        context.insert(CachedQuote(
            symbol: symbol,
            price: price,
            change: 0,
            changePercent: 0,
            currency: "USD",
            providerName: "Test",
            fetchedAt: Date()
        ))
        try context.save()
    }

    // MARK: - Prices

    @Test("Prompt includes symbol+price for symbols with a cached quote")
    func pricedSymbolAppearsInPrompt() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 150
        ))
        try insertCachedQuote(b.context, symbol: "AAPL", price: 185.50)

        // Force the actor to see the newly-inserted row. The actor
        // holds its own ModelContext(modelContainer) — waiting on a
        // `cachedQuote` call forces that context to refetch from store.
        _ = await b.market.cachedQuote(for: "AAPL")

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("## Current Market Prices"))
        #expect(prompt.contains("AAPL"))
        // `MoneyFormatter.string(from:)` uses the current locale; rather
        // than pinning a format, assert the structural symbol:price shape.
        #expect(prompt.contains("- AAPL:"))
    }

    @Test("Prompt omits a price line for symbols without a cached quote")
    func unquotedSymbolIsOmittedFromPricesSection() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 150
        ))
        // Second holding has no cached quote — it must not show up
        // in Current Market Prices.
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "NVDA", assetType: .stock,
            shares: 5, averageCost: 400
        ))
        try insertCachedQuote(b.context, symbol: "AAPL", price: 185.50)
        _ = await b.market.cachedQuote(for: "AAPL")

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("- AAPL:"))
        #expect(prompt.contains("- NVDA:") == false)
    }

    @Test("Prompt omits the Current Market Prices section entirely when nothing has a cached quote")
    func pricesSectionOmittedWhenEmpty() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 150
        ))
        // No cached quote inserted.

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("## Current Market Prices") == false)
    }

    // MARK: - Account Overrides

    @Test("Prompt contains the Account Overrides section when an override exists")
    func overrideSectionAppearsWhenOverrideExists() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .rothIRA, displayName: "Retirement"
        ))
        try b.profile.setOverride(
            for: account,
            riskTolerance: .aggressive,
            horizonPreference: nil,
            cautionBias: nil
        )

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("## Account Overrides"))
        #expect(prompt.contains("Retirement"))
        #expect(prompt.contains("risk: Aggressive"))
    }

    @Test("Prompt omits the Account Overrides section when no overrides exist")
    func overrideSectionOmittedWhenNone() async throws {
        let b = try makeBundle()
        _ = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("## Account Overrides") == false)
    }

    // MARK: - Combined

    @Test("Prompt preserves the existing Portfolio Overview and Holdings sections alongside the new ones")
    func existingSectionsStillRender() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 150
        ))

        let prompt = await b.vm.buildSystemPrompt()

        #expect(prompt.contains("## Portfolio Overview"))
        #expect(prompt.contains("Risk tolerance:"))
        #expect(prompt.contains("## Holdings"))
        #expect(prompt.contains("Main"))
        #expect(prompt.contains("AAPL"))
    }
}
