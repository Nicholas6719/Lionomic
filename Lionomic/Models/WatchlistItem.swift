import Foundation
import SwiftData

@Model
final class WatchlistItem {
    @Attribute(.unique) var id: UUID
    var watchlist: Watchlist?
    var symbol: String
    var assetType: AssetType
    var addedAt: Date
    var notes: String
    var targetBuyBelow: Decimal?
    var alertsEnabled: Bool

    init(
        id: UUID = UUID(),
        watchlist: Watchlist,
        symbol: String,
        assetType: AssetType,
        addedAt: Date = Date(),
        notes: String = "",
        targetBuyBelow: Decimal? = nil,
        alertsEnabled: Bool = false
    ) {
        self.id = id
        self.watchlist = watchlist
        self.symbol = Holding.normalize(symbol: symbol)
        self.assetType = assetType
        self.addedAt = addedAt
        self.notes = notes
        self.targetBuyBelow = targetBuyBelow
        self.alertsEnabled = alertsEnabled
    }
}
