import Foundation
import SwiftData

/// Writes append-only snapshots after portfolio changes.
/// Called by AppEnvironment after a successful holding or contribution commit.
/// Views and ViewModels never call HistoryService directly.
/// All writes are best-effort — snapshot failure never blocks a portfolio commit.
@MainActor
final class HistoryService {

    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func snapshotHolding(_ holding: Holding) {
        let snapshot = HoldingSnapshot(
            holdingID:       holding.id,
            symbol:          holding.symbol,
            assetType:       holding.assetType.rawValue,
            shares:          holding.shares,
            averageCost:     holding.averageCost,
            manualValuation: holding.manualValuation
        )
        context.insert(snapshot)
        try? context.save()
    }

    func snapshotAccount(_ account: Account) {
        let total = account.holdings.reduce(Decimal.zero) { sum, holding in
            if let valuation = holding.manualValuation {
                return sum + valuation
            } else if let shares = holding.shares, let cost = holding.averageCost {
                return sum + (shares * cost)
            }
            return sum
        }
        let snapshot = AccountSnapshot(
            accountID:   account.id,
            accountKind: account.kind.rawValue,
            totalValue:  total
        )
        context.insert(snapshot)
        try? context.save()
    }

    @discardableResult
    func recordContribution(
        to account: Account,
        amount: Decimal,
        note: String = ""
    ) -> ContributionEvent? {
        guard amount > .zero else { return nil }
        let event = ContributionEvent(account: account, amount: amount, note: note)
        context.insert(event)
        do {
            try context.save()
            return event
        } catch {
            return nil
        }
    }
}
