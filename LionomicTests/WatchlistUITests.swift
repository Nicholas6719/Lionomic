import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Repository-level behaviors that the M5 watchlist UI relies on.
/// Same patterns as other test suites: fresh container, fresh context.
@MainActor
struct WatchlistUITests {

    private func makeRepo() throws -> (WatchlistRepository, ModelContext) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let repo = WatchlistRepository(modelContext: context)
        try repo.seedDefaultsIfNeeded()
        return (repo, context)
    }

    @Test("Adding an item to the standard watchlist succeeds")
    func addItemToStandardSucceeds() throws {
        let (repo, _) = try makeRepo()

        let item = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "aapl",
            assetType: .stock
        ))

        #expect(item.symbol == "AAPL")
        #expect(item.watchlist?.kind == .standard)
        // M9: DraftWatchlistItem.alertsEnabled default flipped to true
        // now that notification delivery is wired up.
        #expect(item.alertsEnabled == true)
    }

    @Test("Adding a duplicate symbol to the same watchlist fails with duplicateSymbolInWatchlist")
    func duplicateSymbolFails() throws {
        let (repo, _) = try makeRepo()

        let first = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "NVDA",
            assetType: .stock
        ))

        do {
            _ = try repo.commit(draftItem: DraftWatchlistItem(
                watchlistKind: .standard,
                symbol: "nvda",
                assetType: .stock
            ))
            Issue.record("Expected duplicateSymbolInWatchlist error")
        } catch WatchlistRepositoryError.duplicateSymbolInWatchlist(let existingId) {
            #expect(existingId == first.id)
        }
    }

    @Test("Adding the same symbol to a different watchlist succeeds")
    func sameSymbolDifferentWatchlistSucceeds() throws {
        let (repo, _) = try makeRepo()

        _ = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "TSLA",
            assetType: .stock
        ))
        _ = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity,
            symbol: "TSLA",
            assetType: .stock
        ))

        #expect(try repo.fetchItems(in: .standard).count == 1)
        #expect(try repo.fetchItems(in: .highPriorityOpportunity).count == 1)
    }

    @Test("Removing an item leaves the watchlist with one fewer item")
    func removeItemLeavesOneFewer() throws {
        let (repo, _) = try makeRepo()

        _ = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "SPY",
            assetType: .etf
        ))
        let voo = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "VOO",
            assetType: .etf
        ))

        #expect(try repo.fetchItems(in: .standard).count == 2)
        try repo.commitDelete(voo)
        let remaining = try repo.fetchItems(in: .standard)
        #expect(remaining.count == 1)
        #expect(remaining.first?.symbol == "SPY")
    }

    @Test("NFT items save without targetBuyBelow validation errors")
    func nftSavesWithoutTargetBuyBelow() throws {
        let (repo, _) = try makeRepo()

        let item = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity,
            symbol: "PUNK-123",
            assetType: .nft,
            targetBuyBelow: nil,
            alertsEnabled: false
        ))

        #expect(item.assetType == .nft)
        #expect(item.targetBuyBelow == nil)
    }

    @Test("alertsEnabled defaults to true on a new DraftWatchlistItem (M9)")
    func alertsEnabledDefaultIsTrue() {
        let draft = DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "MSFT",
            assetType: .stock
        )
        // M9: default-on because the alert delivery pipeline is live now.
        #expect(draft.alertsEnabled == true)
        #expect(draft.targetBuyBelow == nil)
        #expect(draft.notes == "")
    }
}
