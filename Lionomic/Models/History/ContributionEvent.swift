import Foundation
import SwiftData

/// Records a single cash contribution to an account.
/// Append-only — never mutated after creation.
/// Created via HistoryService.recordContribution(to:amount:note:).
/// Never inserted directly from a view.
@Model
final class ContributionEvent {

    @Attribute(.unique) var id: UUID
    var account: Account?
    var amount: Decimal
    var occurredAt: Date
    var note: String

    init(account: Account, amount: Decimal, occurredAt: Date = .now, note: String = "") {
        self.id         = UUID()
        self.account    = account
        self.amount     = amount
        self.occurredAt = occurredAt
        self.note       = note
    }
}
