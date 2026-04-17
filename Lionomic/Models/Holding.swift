import Foundation
import SwiftData

@Model
final class Holding {
    @Attribute(.unique) var id: UUID
    var account: Account?
    var symbol: String
    var assetType: AssetType
    var shares: Decimal?
    var averageCost: Decimal?
    var manualValuation: Decimal?
    var valuationUpdatedAt: Date?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        account: Account,
        symbol: String,
        assetType: AssetType,
        shares: Decimal? = nil,
        averageCost: Decimal? = nil,
        manualValuation: Decimal? = nil,
        valuationUpdatedAt: Date? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.account = account
        self.symbol = Self.normalize(symbol: symbol)
        self.assetType = assetType
        self.shares = shares
        self.averageCost = averageCost
        self.manualValuation = manualValuation
        self.valuationUpdatedAt = valuationUpdatedAt
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func normalize(symbol: String) -> String {
        symbol.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
    }
}
