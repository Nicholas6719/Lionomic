import Foundation

/// Output from a single rule firing. Pure value type; the engine collects
/// these and picks a winner by confidence. Internal to the rules layer —
/// persisted supporting outputs use `RecommendationOutput`.
struct RuleOutput: Hashable, Sendable {
    let ruleName: String
    let category: RecommendationCategory
    let reasoning: String
    let confidence: Double
    let cautionNote: String

    init(
        ruleName: String,
        category: RecommendationCategory,
        reasoning: String,
        confidence: Double,
        cautionNote: String = ""
    ) {
        self.ruleName    = ruleName
        self.category    = category
        self.reasoning   = reasoning
        self.confidence  = max(0, min(1, confidence))
        self.cautionNote = cautionNote
    }

    /// Narrow the rule-output to the persisted shape — drops `ruleName` and
    /// widens `confidence` to `Decimal` to match `RecommendationOutput`.
    var asRecommendationOutput: RecommendationOutput {
        RecommendationOutput(
            category: category,
            reasoning: reasoning,
            confidence: Decimal(confidence),
            cautionNote: cautionNote
        )
    }
}

/// Codable value type representing a single rule output in persisted form.
/// Stored on `Recommendation.supportingOutputs` so views, tests, and future
/// consumers can iterate the set of contributing rules without parsing
/// strings. `confidence` is `Decimal` (persisted shape), distinct from
/// the rules-layer `RuleOutput` which carries `Double`.
struct RecommendationOutput: Codable, Hashable, Sendable {
    let category: RecommendationCategory
    let reasoning: String
    let confidence: Decimal
    let cautionNote: String

    init(
        category: RecommendationCategory,
        reasoning: String,
        confidence: Decimal,
        cautionNote: String = ""
    ) {
        self.category    = category
        self.reasoning   = reasoning
        self.confidence  = confidence
        self.cautionNote = cautionNote
    }
}

/// A single rule. Returns `nil` when it has no opinion on the holding.
/// Implementations rely on project-default MainActor isolation so they can
/// touch `Account.holdings` and other SwiftData relationships safely.
///
/// MProfile: `profile` is now an `EffectiveProfile` — the global
/// `InvestingProfile` merged with any per-account override. Rules no
/// longer see the raw `InvestingProfile`; they see the resolved view.
protocol RecommendationRule {
    var name: String { get }

    func evaluate(
        holding: Holding,
        account: Account,
        profile: EffectiveProfile,
        quote: QuoteResult?
    ) -> RuleOutput?
}

/// Shared helpers for rules. Kept here so every rule computes value the
/// same way (Holding has no `costBasis` helper — rules must not duplicate
/// the formula inline).
enum RuleMath {
    /// Cost basis = shares × averageCost. Returns 0 when either is missing.
    static func costBasis(_ holding: Holding) -> Decimal {
        guard let shares = holding.shares, let cost = holding.averageCost else { return 0 }
        return shares * cost
    }

    /// Best-effort estimated value for a single holding.
    /// - NFT: `manualValuation ?? 0`.
    /// - Non-NFT with live quote and shares: `shares × price`.
    /// - Non-NFT otherwise: cost basis.
    static func estimatedValue(_ holding: Holding, quote: QuoteResult?) -> Decimal {
        if !holding.assetType.usesMarketQuote {
            return holding.manualValuation ?? 0
        }
        if let shares = holding.shares, let quote {
            return shares * quote.price
        }
        return costBasis(holding)
    }
}
