import Foundation

/// Fires when the user has opted into dip-buying (`profile.preferDipBuying`)
/// and the live quote shows the asset down more than 3% today.
///
/// Output depends on `profile.cautionBias`:
///   - aggressive → `.buyNow`
///   - cautious / balanced → `.wait` (a softer nudge)
///
/// Remember `QuoteResult.changePercent` is a **ratio** (e.g. -0.03 = -3%).
nonisolated struct DipBuyRule: RecommendationRule {
    let name = "DipBuy"

    static let dipThresholdRatio: Decimal = -0.03

    func evaluate(
        holding: Holding,
        account: Account,
        profile: InvestingProfile,
        quote: QuoteResult?
    ) -> RuleOutput? {
        guard profile.preferDipBuying else { return nil }
        guard holding.assetType.usesMarketQuote else { return nil }
        guard let quote else { return nil }
        guard quote.changePercent < Self.dipThresholdRatio else { return nil }

        let pctDown = NSDecimalNumber(decimal: abs(quote.changePercent) * 100).doubleValue
        let pctString = String(format: "%.1f%%", pctDown)

        switch profile.cautionBias {
        case .aggressive:
            return RuleOutput(
                ruleName: name,
                category: .buyNow,
                reasoning: "\(holding.symbol) is down \(pctString) today. Your profile favors buying dips aggressively.",
                confidence: 0.7
            )
        case .balanced, .cautious:
            return RuleOutput(
                ruleName: name,
                category: .wait,
                reasoning: "\(holding.symbol) is down \(pctString) today. Your profile likes dips but prefers measured entries — consider waiting for confirmation.",
                confidence: 0.6
            )
        }
    }
}
