import Foundation

/// Output from a single rule firing. Pure value type; the engine collects
/// these and picks a winner by confidence.
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
}

/// A single rule. Returns `nil` when it has no opinion on the holding.
/// Implementations rely on project-default MainActor isolation so they can
/// touch `Account.holdings` and other SwiftData relationships safely.
protocol RecommendationRule {
    var name: String { get }

    func evaluate(
        holding: Holding,
        account: Account,
        profile: InvestingProfile,
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
