import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct DashboardTests {

    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        return ModelContext(container)
    }

    // MARK: - Portfolio Summary

    @Test("Portfolio summary total calculates correctly with mixed NFT and non-NFT holdings")
    func portfolioTotalWithMixedHoldings() throws {
        let context = try makeContext()
        let account = Account(kind: .brokerage, displayName: "Brokerage")
        context.insert(account)

        // Non-NFT with live quote: 10 shares @ quoted $150 = 1500
        let aapl = Holding(account: account, symbol: "AAPL", assetType: .stock)
        aapl.shares = 10
        aapl.averageCost = 140   // ignored when live quote is available
        context.insert(aapl)

        // Non-NFT without live quote: falls back to cost basis 5 * 200 = 1000
        let msft = Holding(account: account, symbol: "MSFT", assetType: .stock)
        msft.shares = 5
        msft.averageCost = 200
        context.insert(msft)

        // NFT: manual valuation 750
        let nft = Holding(account: account, symbol: "PUNK-1", assetType: .nft)
        nft.manualValuation = 750
        context.insert(nft)

        try context.save()

        let quotes: [String: QuoteResult] = [
            "AAPL": QuoteResult(symbol: "AAPL", price: 150, change: 0, changePercent: 0,
                                currency: "USD", fetchedAt: Date(), providerName: "Primary")
        ]
        let totals = PortfolioValuation.totals(for: [account], quoteFor: { quotes[$0] })

        // Use NSDecimalNumber so Decimal normalization differences
        // (mantissa/exponent) can't masquerade as inequality.
        #expect(NSDecimalNumber(decimal: totals.total) == NSDecimalNumber(value: 3250))
        #expect(totals.breakdown.count == 1)
        #expect(NSDecimalNumber(decimal: totals.breakdown[0].total) == NSDecimalNumber(value: 3250))
    }

    @Test("Portfolio summary shows zero when no accounts exist")
    func portfolioTotalWithNoAccounts() {
        let totals = PortfolioValuation.totals(for: [])
        #expect(totals.total == 0)
        #expect(totals.breakdown.isEmpty)
    }

    @Test("Portfolio summary with account but no holdings returns zero")
    func portfolioTotalEmptyAccount() throws {
        let context = try makeContext()
        let account = Account(kind: .rothIRA, displayName: "Roth")
        context.insert(account)
        try context.save()

        let totals = PortfolioValuation.totals(for: [account])
        #expect(totals.total == 0)
        #expect(totals.breakdown.count == 1)
        #expect(totals.breakdown[0].total == 0)
    }

    // MARK: - Watchlist highlights

    @Test("Watchlist highlights returns at most 3 items from high-priority watchlist")
    func watchlistHighlightsCaps() throws {
        let context = try makeContext()
        let repo = WatchlistRepository(modelContext: context)
        try repo.seedDefaultsIfNeeded()

        for symbol in ["AAA", "BBB", "CCC", "DDD", "EEE"] {
            _ = try repo.commit(draftItem: DraftWatchlistItem(
                watchlistKind: .highPriorityOpportunity,
                symbol: symbol,
                assetType: .stock
            ))
        }

        let items = try repo.fetchItems(in: .highPriorityOpportunity)
        #expect(items.count == 5)

        // Card shows prefix(3) — verify the sort order is deterministic (by addedAt).
        let first3 = Array(items.prefix(3))
        #expect(first3.count == 3)
        #expect(first3.map(\.symbol) == ["AAA", "BBB", "CCC"])
    }
}
