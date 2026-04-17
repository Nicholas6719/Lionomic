import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct WatchlistRepositoryTests {
    private func makeRepo() throws -> (WatchlistRepository, ModelContext) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (WatchlistRepository(modelContext: context), context)
    }

    @Test func seedingCreatesExactlyOneOfEachKind() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()

        let all = try repo.fetchAllWatchlists()
        #expect(all.count == WatchlistKind.allCases.count)
        #expect(Set(all.map(\.kind)) == Set(WatchlistKind.allCases))
    }

    @Test func seedingIsIdempotent() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()
        try repo.seedDefaultsIfNeeded()
        try repo.seedDefaultsIfNeeded()

        let all = try repo.fetchAllWatchlists()
        #expect(all.count == WatchlistKind.allCases.count)
    }

    @Test func addItemToStandardWatchlist() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()

        let item = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard,
            symbol: "msft",
            assetType: .stock
        ))

        #expect(item.symbol == "MSFT")
        #expect(item.watchlist?.kind == .standard)
        let items = try repo.fetchItems(in: .standard)
        #expect(items.count == 1)
        #expect(try repo.fetchItems(in: .highPriorityOpportunity).isEmpty)
    }

    @Test func duplicateSymbolInSameWatchlistIsRejected() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()

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
            Issue.record("Expected duplicate-symbol throw")
        } catch WatchlistRepositoryError.duplicateSymbolInWatchlist(let existingId) {
            #expect(existingId == first.id)
        }
    }

    @Test func sameSymbolAllowedAcrossDifferentWatchlists() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()

        _ = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "TSLA", assetType: .stock
        ))
        _ = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .highPriorityOpportunity, symbol: "TSLA", assetType: .stock
        ))

        #expect(try repo.fetchItems(in: .standard).count == 1)
        #expect(try repo.fetchItems(in: .highPriorityOpportunity).count == 1)
    }

    @Test func deletingItemRemovesItFromWatchlist() async throws {
        let (repo, _) = try makeRepo()
        try repo.seedDefaultsIfNeeded()

        let item = try repo.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))

        try repo.commitDelete(item)

        #expect(try repo.fetchItems(in: .standard).isEmpty)
    }
}
