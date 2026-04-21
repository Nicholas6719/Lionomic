import Foundation

/// Pure, stateless orchestrator. Runs every rule against a holding and
/// picks a winner by confidence. Rules are injected at init so tests can
/// swap them without subclassing.
///
/// Aggregation rules:
///   - No rules fire → `.hold` + "No signals detected."
///   - One rule fires → that output wins; `supportingOutputs` is empty.
///   - Multiple rules fire → highest-confidence output wins; the others
///     are stored as structured `RecommendationOutput` entries on
///     `Recommendation.supportingOutputs`. `reasoning` holds only the
///     winning rule's text — no string concatenation.
///   - NFT clamp: after aggregation, if the holding is an NFT and the
///     winning category is outside `{hold, researchMore, reduce}`, it is
///     rewritten to `.researchMore`.
nonisolated struct RecommendationEngine {

    let rules: [any RecommendationRule]

    /// Production default: all five M7 rules in a reasonable order.
    nonisolated static func defaultRules() -> [any RecommendationRule] {
        [
            InsufficientDataRule(),
            OverconcentrationRule(),
            DipBuyRule(),
            NoChaseRule(),
            RothLongTermBiasRule(),
        ]
    }

    nonisolated init(rules: [any RecommendationRule] = RecommendationEngine.defaultRules()) {
        self.rules = rules
    }

    @MainActor
    func evaluate(
        holding: Holding,
        account: Account,
        profile: EffectiveProfile,
        quote: QuoteResult?,
        at date: Date = .now
    ) -> Recommendation {
        let outputs = rules.compactMap {
            $0.evaluate(holding: holding, account: account, profile: profile, quote: quote)
        }

        let primary: RuleOutput
        let supporting: [RecommendationOutput]
        if outputs.isEmpty {
            primary = RuleOutput(
                ruleName: "Default",
                category: .hold,
                reasoning: "No signals detected.",
                confidence: 0.5
            )
            supporting = []
        } else {
            let sorted = outputs.sorted { $0.confidence > $1.confidence }
            primary = sorted[0]
            supporting = sorted.dropFirst().map { $0.asRecommendationOutput }
        }

        let clampedCategory = Self.clamp(primary.category, for: holding.assetType)

        return Recommendation(
            holdingID: holding.id,
            accountID: account.id,
            symbol: holding.symbol,
            assetType: holding.assetType,
            category: clampedCategory,
            reasoning: primary.reasoning,
            confidence: primary.confidence,
            cautionNote: primary.cautionNote,
            supportingOutputs: supporting,
            generatedAt: date
        )
    }

    /// NFT clamp: NFTs only get qualitative recommendations
    /// (`hold`, `researchMore`, `reduce`). Anything else → `researchMore`.
    static func clamp(
        _ category: RecommendationCategory,
        for assetType: AssetType
    ) -> RecommendationCategory {
        guard assetType == .nft else { return category }
        switch category {
        case .hold, .researchMore, .reduce:
            return category
        case .buyNow, .wait, .avoid:
            return .researchMore
        }
    }
}
