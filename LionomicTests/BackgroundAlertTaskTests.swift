import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Unit tests for `BackgroundAlertTask.collectAlertSymbols(...)`. The
/// actual BGTask registration / scheduling is not unit-testable (requires
/// a live `BGTaskScheduler`), but the symbol-collection helper is pure
/// SwiftData fetching + filtering and is exercised end-to-end here.
@MainActor
struct BackgroundAlertTaskTests {

    private struct Bundle {
        let context: ModelContext
        let portfolio: PortfolioRepository
        let watchlist: WatchlistRepository
        let profile: ProfileRepository
    }

    private func makeBundle() throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profile = ProfileRepository(modelContext: context)
        _ = try profile.commit(draft: DraftProfile())
        let watchlist = WatchlistRepository(modelContext: context)
        try watchlist.seedDefaultsIfNeeded()
        let portfolio = PortfolioRepository(modelContext: context, profileRepository: profile)
        return Bundle(context: context, portfolio: portfolio, watchlist: watchlist, profile: profile)
    }

    @Test("collectAlertSymbols returns only symbols with at least one non-nil threshold, deduplicated")
    func onlyThresholdedSymbolsAreCollected() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))

        // AAPL: alertAbove set → included
        let aapl = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        try b.portfolio.setAlertThresholds(for: aapl, above: 200, below: nil)

        // NVDA: no thresholds → excluded
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "NVDA", assetType: .stock,
            shares: 1, averageCost: 100
        ))

        // TSLA: alertBelow set → included
        let tsla = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "TSLA", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        try b.portfolio.setAlertThresholds(for: tsla, above: nil, below: 50)

        // Watchlist — SPY with below threshold → included; QQQ without → excluded
        let spy = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))
        try b.watchlist.setAlertThresholds(for: spy, above: 500, below: nil)

        _ = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity, symbol: "QQQ", assetType: .etf
        ))

        // AAPL also on the watchlist → duplicate should be deduped away
        let aaplWatch = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity, symbol: "AAPL", assetType: .stock
        ))
        try b.watchlist.setAlertThresholds(for: aaplWatch, above: 250, below: nil)

        let symbols = BackgroundAlertTask.collectAlertSymbols(
            modelContext: b.context,
            includeHoldings: true,
            includeWatchlist: true
        )

        #expect(symbols == ["AAPL", "SPY", "TSLA"])
    }

    @Test("collectAlertSymbols excludes holdings when includeHoldings is false")
    func holdingsSkippedWhenFlagOff() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        let aapl = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        try b.portfolio.setAlertThresholds(for: aapl, above: 200, below: nil)

        let spy = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))
        try b.watchlist.setAlertThresholds(for: spy, above: 500, below: nil)

        let symbols = BackgroundAlertTask.collectAlertSymbols(
            modelContext: b.context,
            includeHoldings: false,
            includeWatchlist: true
        )

        #expect(symbols == ["SPY"])
    }

    @Test("collectAlertSymbols excludes watchlist when includeWatchlist is false")
    func watchlistSkippedWhenFlagOff() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        let aapl = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        try b.portfolio.setAlertThresholds(for: aapl, above: 200, below: nil)

        let spy = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))
        try b.watchlist.setAlertThresholds(for: spy, above: 500, below: nil)

        let symbols = BackgroundAlertTask.collectAlertSymbols(
            modelContext: b.context,
            includeHoldings: true,
            includeWatchlist: false
        )

        #expect(symbols == ["AAPL"])
    }

    @Test("collectAlertSymbols returns empty when no thresholds are set anywhere")
    func emptyWhenNothingConfigured() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        _ = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        _ = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))

        let symbols = BackgroundAlertTask.collectAlertSymbols(
            modelContext: b.context,
            includeHoldings: true,
            includeWatchlist: true
        )

        #expect(symbols.isEmpty)
    }
}
