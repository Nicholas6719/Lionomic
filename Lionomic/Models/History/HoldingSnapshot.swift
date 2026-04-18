import Foundation
import SwiftData

/// A point-in-time value snapshot for a single holding.
/// Append-only. HistoryService writes one after each holding commit.
/// holdingID is stored as UUID (not a relationship) so history survives holding deletion.
@Model
final class HoldingSnapshot {

    @Attribute(.unique) var id: UUID
    var holdingID: UUID
    var symbol: String
    var assetType: String          // raw String — safe for SwiftData
    var shares: Decimal?
    var averageCost: Decimal?
    var manualValuation: Decimal?
    var snapshotAt: Date

    init(
        holdingID: UUID,
        symbol: String,
        assetType: String,
        shares: Decimal?,
        averageCost: Decimal?,
        manualValuation: Decimal?,
        snapshotAt: Date = .now
    ) {
        self.id              = UUID()
        self.holdingID       = holdingID
        self.symbol          = symbol
        self.assetType       = assetType
        self.shares          = shares
        self.averageCost     = averageCost
        self.manualValuation = manualValuation
        self.snapshotAt      = snapshotAt
    }
}
