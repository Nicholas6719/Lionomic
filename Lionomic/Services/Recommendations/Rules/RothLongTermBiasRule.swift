import Foundation

/// For Roth IRA holdings only: nudges a user with a `.short` horizon
/// preference toward thinking long-term, since Roth accounts draw their
/// tax advantage from long-term compounding.
nonisolated struct RothLongTermBiasRule: RecommendationRule {
    let name = "RothLongTermBias"

    func evaluate(
        holding: Holding,
        account: Account,
        profile: InvestingProfile,
        quote: QuoteResult?
    ) -> RuleOutput? {
        guard account.kind == .rothIRA else { return nil }
        guard profile.horizonPreference == .short else { return nil }

        return RuleOutput(
            ruleName: name,
            category: .hold,
            reasoning: "\(holding.symbol) is in your \(account.displayName) Roth account. Roth IRAs reward long-term holding through tax-free growth — short-term trades give up that benefit.",
            confidence: 0.55,
            cautionNote: "Consider your overall retirement timeline."
        )
    }
}
