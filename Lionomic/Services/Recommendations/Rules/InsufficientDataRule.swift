import Foundation

/// Fires when a non-NFT holding has no live quote and no average cost —
/// there isn't enough information to reason about it at all.
nonisolated struct InsufficientDataRule: RecommendationRule {
    let name = "InsufficientData"

    func evaluate(
        holding: Holding,
        account: Account,
        profile: EffectiveProfile,
        quote: QuoteResult?
    ) -> RuleOutput? {
        guard holding.assetType.usesMarketQuote else { return nil }
        guard quote == nil && holding.averageCost == nil else { return nil }

        return RuleOutput(
            ruleName: name,
            category: .researchMore,
            reasoning: "Not enough data to evaluate \(holding.symbol). Add an average cost or fetch a live quote to unlock recommendations.",
            confidence: 0.3
        )
    }
}
