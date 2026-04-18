import Foundation
import SwiftData

/// A point-in-time total-value snapshot for an account.
/// Append-only. totalValue uses cost basis for non-NFT holdings with no live quote.
/// accountID stored as UUID (not a relationship).
@Model
final class AccountSnapshot {

    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var accountKind: String        // raw String — safe for SwiftData
    var totalValue: Decimal
    var snapshotAt: Date

    init(
        accountID: UUID,
        accountKind: String,
        totalValue: Decimal,
        snapshotAt: Date = .now
    ) {
        self.id          = UUID()
        self.accountID   = accountID
        self.accountKind = accountKind
        self.totalValue  = totalValue
        self.snapshotAt  = snapshotAt
    }
}
