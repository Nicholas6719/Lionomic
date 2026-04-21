import Foundation
import SwiftData

struct DraftWatchlistItem: Hashable {
    var id: UUID?
    var watchlistKind: WatchlistKind
    var symbol: String
    var assetType: AssetType
    var notes: String
    var targetBuyBelow: Decimal?
    var alertsEnabled: Bool

    init(
        id: UUID? = nil,
        watchlistKind: WatchlistKind,
        symbol: String,
        assetType: AssetType,
        notes: String = "",
        targetBuyBelow: Decimal? = nil,
        alertsEnabled: Bool = true   // M9: default-on now that alert delivery is wired up
    ) {
        self.id = id
        self.watchlistKind = watchlistKind
        self.symbol = symbol
        self.assetType = assetType
        self.notes = notes
        self.targetBuyBelow = targetBuyBelow
        self.alertsEnabled = alertsEnabled
    }

    init(editing item: WatchlistItem) {
        self.id = item.id
        self.watchlistKind = item.watchlist?.kind ?? .standard
        self.symbol = item.symbol
        self.assetType = item.assetType
        self.notes = item.notes
        self.targetBuyBelow = item.targetBuyBelow
        self.alertsEnabled = item.alertsEnabled
    }

    var normalizedSymbol: String {
        Holding.normalize(symbol: symbol)
    }
}

enum WatchlistRepositoryError: Error, Equatable {
    case watchlistNotFound
    case itemNotFound
    case duplicateSymbolInWatchlist(existingItemId: UUID)
    case emptySymbol
}

@MainActor
final class WatchlistRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Creates the standard + high-priority watchlists if they do not already exist.
    /// Idempotent: repeated calls leave exactly one of each kind.
    func seedDefaultsIfNeeded() throws {
        let existingKinds = Set(try fetchAllWatchlists().map(\.kind))
        for kind in WatchlistKind.allCases where !existingKinds.contains(kind) {
            modelContext.insert(Watchlist(kind: kind))
        }
        try modelContext.save()
    }

    func fetchAllWatchlists() throws -> [Watchlist] {
        try modelContext.fetch(FetchDescriptor<Watchlist>())
    }

    func fetchWatchlist(kind: WatchlistKind) throws -> Watchlist? {
        try fetchAllWatchlists().first { $0.kind == kind }
    }

    func fetchItems(in kind: WatchlistKind) throws -> [WatchlistItem] {
        guard let watchlist = try fetchWatchlist(kind: kind) else {
            throw WatchlistRepositoryError.watchlistNotFound
        }
        return watchlist.items.sorted { $0.addedAt < $1.addedAt }
    }

    func fetchItem(id: UUID) throws -> WatchlistItem? {
        let descriptor = FetchDescriptor<WatchlistItem>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchItem(in kind: WatchlistKind, symbol: String) throws -> WatchlistItem? {
        guard let watchlist = try fetchWatchlist(kind: kind) else { return nil }
        let normalized = Holding.normalize(symbol: symbol)
        return watchlist.items.first { $0.symbol == normalized }
    }

    @discardableResult
    func commit(draftItem draft: DraftWatchlistItem) throws -> WatchlistItem {
        let normalized = draft.normalizedSymbol
        guard !normalized.isEmpty else {
            throw WatchlistRepositoryError.emptySymbol
        }
        guard let watchlist = try fetchWatchlist(kind: draft.watchlistKind) else {
            throw WatchlistRepositoryError.watchlistNotFound
        }

        if let id = draft.id {
            guard let existing = try fetchItem(id: id) else {
                throw WatchlistRepositoryError.itemNotFound
            }
            if existing.symbol != normalized,
               let conflict = try fetchItem(in: draft.watchlistKind, symbol: normalized) {
                throw WatchlistRepositoryError.duplicateSymbolInWatchlist(
                    existingItemId: conflict.id
                )
            }
            existing.symbol = normalized
            existing.assetType = draft.assetType
            existing.notes = draft.notes
            existing.targetBuyBelow = draft.targetBuyBelow
            existing.alertsEnabled = draft.alertsEnabled
            try modelContext.save()
            return existing
        }

        if let conflict = try fetchItem(in: draft.watchlistKind, symbol: normalized) {
            throw WatchlistRepositoryError.duplicateSymbolInWatchlist(
                existingItemId: conflict.id
            )
        }

        let new = WatchlistItem(
            watchlist: watchlist,
            symbol: normalized,
            assetType: draft.assetType,
            notes: draft.notes,
            targetBuyBelow: draft.targetBuyBelow,
            alertsEnabled: draft.alertsEnabled
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    func commitDelete(_ item: WatchlistItem) throws {
        modelContext.delete(item)
        try modelContext.save()
    }

    // MARK: - Price alert thresholds (MAlerts2)

    /// Sets (or clears, via `nil`) the above/below price alert thresholds
    /// on a `WatchlistItem`. Persists immediately. Same rationale as the
    /// PortfolioRepository equivalent — these are scalar edits with their
    /// own confirm step at the sheet level.
    func setAlertThresholds(
        for item: WatchlistItem,
        above: Decimal?,
        below: Decimal?
    ) throws {
        item.alertAbovePrice = above
        item.alertBelowPrice = below
        try modelContext.save()
    }
}
