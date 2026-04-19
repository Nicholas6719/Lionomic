import Foundation

/// Fires when a single holding exceeds the user's concentration threshold
/// for its account. Threshold scales with `profile.concentrationSensitivity`:
///   - low    → 30%
///   - medium → 20%
///   - high   → 15%
/// Confidence scales with how far over the threshold the holding sits —
/// at the threshold: 0.6, capped at 0.95 for severe overconcentration.
nonisolated struct OverconcentrationRule: RecommendationRule {
    let name = "Overconcentration"

    func evaluate(
        holding: Holding,
        account: Account,
        profile: InvestingProfile,
        quote: QuoteResult?
    ) -> RuleOutput? {
        let thresholdRatio = Self.threshold(for: profile.concentrationSensitivity)

        let holdingValue = RuleMath.estimatedValue(holding, quote: quote)
        guard holdingValue > 0 else { return nil }

        let accountTotal = account.holdings.reduce(Decimal.zero) { sum, h in
            // For other holdings we don't have a quote — use cost basis / manual valuation.
            // The holding being evaluated is the only one we can price off the live quote.
            if h.id == holding.id {
                return sum + holdingValue
            }
            return sum + RuleMath.estimatedValue(h, quote: nil)
        }

        guard accountTotal > 0 else { return nil }

        let ratio = NSDecimalNumber(decimal: holdingValue / accountTotal).doubleValue
        guard ratio > thresholdRatio else { return nil }

        let overBy = ratio - thresholdRatio
        let confidence = min(0.95, 0.6 + overBy * 2)

        let pct = Int((ratio * 100).rounded())
        let thresholdPct = Int((thresholdRatio * 100).rounded())
        let reasoning = "\(holding.symbol) is \(pct)% of \(account.displayName), above your \(thresholdPct)% concentration threshold. Consider trimming."

        return RuleOutput(
            ruleName: name,
            category: .reduce,
            reasoning: reasoning,
            confidence: confidence
        )
    }

    private static func threshold(for sensitivity: ConcentrationSensitivity) -> Double {
        switch sensitivity {
        case .low:    return 0.30
        case .medium: return 0.20
        case .high:   return 0.15
        }
    }
}
