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

    /// MAlerts2: fire a `.watchlistAlert` when the quote crosses above
    /// this value. Nil = no upper threshold.
    var alertAbovePrice: Decimal?
    /// MAlerts2: fire a `.watchlistAlert` when the quote crosses below
    /// this value. Nil = no lower threshold. Note: distinct from
    /// `targetBuyBelow` — the legacy "buy below" pill is a passive
    /// display label, while `alertBelowPrice` drives notification delivery.
    var alertBelowPrice: Decimal?

    init(
        id: UUID = UUID(),
        watchlist: Watchlist,
        symbol: String,
        assetType: AssetType,
        addedAt: Date = Date(),
        notes: String = "",
        targetBuyBelow: Decimal? = nil,
        alertsEnabled: Bool = false,
        alertAbovePrice: Decimal? = nil,
        alertBelowPrice: Decimal? = nil
    ) {
        self.id = id
        self.watchlist = watchlist
        self.symbol = Holding.normalize(symbol: symbol)
        self.assetType = assetType
        self.addedAt = addedAt
        self.notes = notes
        self.targetBuyBelow = targetBuyBelow
        self.alertsEnabled = alertsEnabled
        self.alertAbovePrice = alertAbovePrice
        self.alertBelowPrice = alertBelowPrice
    }
}
