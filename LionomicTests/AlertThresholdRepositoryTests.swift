import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Verifies that the MAlerts2 additions to `PortfolioRepository` and
/// `WatchlistRepository` persist the `alertAbovePrice` / `alertBelowPrice`
/// thresholds correctly and that clearing them via `nil` removes them.
@MainActor
struct AlertThresholdRepositoryTests {

    private struct Bundle {
        let portfolio: PortfolioRepository
        let watchlist: WatchlistRepository
        let context: ModelContext
    }

    private func makeBundle() throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let portfolio = PortfolioRepository(modelContext: context)
        let watchlist = WatchlistRepository(modelContext: context)
        try watchlist.seedDefaultsIfNeeded()
        return Bundle(portfolio: portfolio, watchlist: watchlist, context: context)
    }

    // MARK: - Holding

    @Test func settingAlertAboveOnHoldingPersists() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        let holding = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 100
        ))

        try b.portfolio.setAlertThresholds(for: holding, above: 200, below: nil)

        let refetched = try #require(try b.portfolio.fetchHolding(id: holding.id))
        #expect(refetched.alertAbovePrice == Decimal(200))
        #expect(refetched.alertBelowPrice == nil)
    }

    @Test func settingAlertBelowOnWatchlistItemPersists() throws {
        let b = try makeBundle()
        let item = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "NVDA", assetType: .stock
        ))

        try b.watchlist.setAlertThresholds(for: item, above: nil, below: 500)

        let refetched = try #require(try b.watchlist.fetchItem(id: item.id))
        #expect(refetched.alertBelowPrice == Decimal(500))
        #expect(refetched.alertAbovePrice == nil)
    }

    // MARK: - Clearing

    @Test func clearingThresholdsWithNilRemovesThem() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        let holding = try b.portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 100
        ))

        // Set both, then clear both.
        try b.portfolio.setAlertThresholds(for: holding, above: 200, below: 50)
        try b.portfolio.setAlertThresholds(for: holding, above: nil, below: nil)

        let refetched = try #require(try b.portfolio.fetchHolding(id: holding.id))
        #expect(refetched.alertAbovePrice == nil)
        #expect(refetched.alertBelowPrice == nil)
    }

    @Test func clearingWatchlistThresholdsWithNilRemovesThem() throws {
        let b = try makeBundle()
        let item = try b.watchlist.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity, symbol: "SPY", assetType: .etf
        ))

        try b.watchlist.setAlertThresholds(for: item, above: 500, below: 400)
        try b.watchlist.setAlertThresholds(for: item, above: nil, below: nil)

        let refetched = try #require(try b.watchlist.fetchItem(id: item.id))
        #expect(refetched.alertAbovePrice == nil)
        #expect(refetched.alertBelowPrice == nil)
    }
}
