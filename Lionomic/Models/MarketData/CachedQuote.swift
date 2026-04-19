import Foundation
import SwiftData

/// Persistent cache row for the most recent quote seen for a given symbol.
/// One row per symbol — `.unique` upserts replace the previous value on store.
@Model
final class CachedQuote {

    @Attribute(.unique) var symbol: String
    var price: Decimal
    var change: Decimal
    var changePercent: Decimal
    var currency: String
    var providerName: String
    var fetchedAt: Date

    init(
        symbol: String,
        price: Decimal,
        change: Decimal,
        changePercent: Decimal,
        currency: String,
        providerName: String,
        fetchedAt: Date
    ) {
        self.symbol        = symbol
        self.price         = price
        self.change        = change
        self.changePercent = changePercent
        self.currency      = currency
        self.providerName  = providerName
        self.fetchedAt     = fetchedAt
    }

    /// Freshness check — 60 s window per the M4 cache policy.
    var isFresh: Bool {
        Date().timeIntervalSince(fetchedAt) < QuoteResult.freshnessWindow
    }

    func toResult() -> QuoteResult {
        QuoteResult(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            currency: currency,
            fetchedAt: fetchedAt,
            providerName: providerName
        )
    }
}
