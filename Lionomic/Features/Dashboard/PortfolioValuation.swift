import Foundation

/// Pure computation for portfolio totals.
///
/// Blending rules for each holding:
///   - NFT: `manualValuation` (or 0 if absent).
///   - Non-NFT with a *fresh* cached quote (< 60 s): `shares × quote.price`.
///   - Non-NFT without a fresh quote: cost basis `shares × averageCost`
///     (falls back to 0 if either is missing).
///
/// Accepts a closure for cached-quote lookup so this function stays synchronous
/// and testable without reaching into the actor-isolated `MarketDataService`.
enum PortfolioValuation {

    struct AccountBreakdown: Identifiable, Hashable {
        let id: UUID
        let displayName: String
        let total: Decimal
    }

    struct Totals: Hashable {
        let total: Decimal
        let breakdown: [AccountBreakdown]
    }

    /// - Parameters:
    ///   - accounts: All accounts to include.
    ///   - quoteFor: Lookup for a cached `QuoteResult` by symbol. Only fresh
    ///     quotes should be returned by the caller (freshness is the caller's
    ///     responsibility so this function stays time-agnostic for testing).
    static func totals(
        for accounts: [Account],
        quoteFor: (String) -> QuoteResult? = { _ in nil }
    ) -> Totals {
        var accountTotals: [AccountBreakdown] = []
        var grand: Decimal = 0
        for account in accounts {
            let subtotal = value(of: account, quoteFor: quoteFor)
            accountTotals.append(AccountBreakdown(
                id: account.id,
                displayName: account.displayName,
                total: subtotal
            ))
            grand += subtotal
        }
        return Totals(total: grand, breakdown: accountTotals)
    }

    private static func value(
        of account: Account,
        quoteFor: (String) -> QuoteResult?
    ) -> Decimal {
        account.holdings.reduce(Decimal.zero) { sum, holding in
            sum + value(of: holding, quoteFor: quoteFor)
        }
    }

    private static func value(
        of holding: Holding,
        quoteFor: (String) -> QuoteResult?
    ) -> Decimal {
        if !holding.assetType.usesMarketQuote {
            return holding.manualValuation ?? 0
        }
        if let shares = holding.shares, let quote = quoteFor(holding.symbol) {
            return shares * quote.price
        }
        if let shares = holding.shares, let cost = holding.averageCost {
            return shares * cost
        }
        return 0
    }
}
