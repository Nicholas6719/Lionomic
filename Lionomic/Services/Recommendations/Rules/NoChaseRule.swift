import Foundation

/// Fires when the live quote is up more than 5% today — warns against
/// chasing a strong up day. Outputs `.wait`; never turns a hot day into
/// a `.buyNow`.
///
/// `QuoteResult.changePercent` is a **ratio** (e.g. 0.05 = 5%).
nonisolated struct NoChaseRule: RecommendationRule {
    let name = "NoChase"

    static let chaseThresholdRatio: Decimal = 0.05

    func evaluate(
        holding: Holding,
        account: Account,
        profile: EffectiveProfile,
        quote: QuoteResult?
    ) -> RuleOutput? {
        guard holding.assetType.usesMarketQuote else { return nil }
        guard let quote else { return nil }
        guard quote.changePercent > Self.chaseThresholdRatio else { return nil }

        let pctUp = NSDecimalNumber(decimal: quote.changePercent * 100).doubleValue
        let pctString = String(format: "%.1f%%", pctUp)

        return RuleOutput(
            ruleName: name,
            category: .wait,
            reasoning: "\(holding.symbol) is up \(pctString) today — a strong move. Chasing momentum rarely pays.",
            confidence: 0.65,
            cautionNote: "Prices can reverse quickly."
        )
    }
}
