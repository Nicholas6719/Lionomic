import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct RecommendationEngineTests {

    // MARK: - Helpers

    private func makeEverything(
        assetType: AssetType = .stock,
        accountKind: AccountKind = .brokerage
    ) throws -> (Holding, Account) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let repo = PortfolioRepository(modelContext: context)
        let account = try repo.commit(draftAccount: DraftAccount(
            kind: accountKind, displayName: "Test"
        ))
        let holding: Holding
        if assetType == .nft {
            holding = try repo.commit(draftHolding: DraftHolding(
                accountID: account.id,
                symbol: "BORED",
                assetType: .nft,
                manualValuation: 1000
            ))
        } else {
            holding = try repo.commit(draftHolding: DraftHolding(
                accountID: account.id,
                symbol: "AAPL",
                assetType: assetType,
                shares: 10,
                averageCost: 100
            ))
        }
        return (holding, account)
    }

    private func quote(_ percent: Decimal) -> QuoteResult {
        QuoteResult(
            symbol: "AAPL",
            price: 100,
            change: 0,
            changePercent: percent,
            currency: "USD",
            fetchedAt: Date(),
            providerName: "Test"
        )
    }

    // MARK: - No-rules-fire baseline

    @Test func noRulesFireProducesHoldWithDefaultReasoning() async throws {
        let (holding, account) = try makeEverything()
        let engine = RecommendationEngine(rules: [])
        let rec = engine.evaluate(
            holding: holding,
            account: account,
            profile: InvestingProfile(),
            quote: nil
        )
        #expect(rec.categoryEnum == .hold)
        #expect(rec.reasoning.contains("No signals detected"))
    }

    // MARK: - NFT clamp

    @Test func nftHoldingClampsBuyNowToResearchMore() async throws {
        let (holding, account) = try makeEverything(assetType: .nft)

        // A fake rule that always returns .buyNow at high confidence.
        struct FakeBuyNowRule: RecommendationRule {
            let name = "FakeBuyNow"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .buyNow, reasoning: "always buy", confidence: 0.9)
            }
        }

        let engine = RecommendationEngine(rules: [FakeBuyNowRule()])
        let rec = engine.evaluate(
            holding: holding,
            account: account,
            profile: InvestingProfile(),
            quote: nil
        )
        #expect(rec.categoryEnum == .researchMore)
    }

    @Test func nftAllowsHoldAndReduceThrough() async throws {
        let (holding, account) = try makeEverything(assetType: .nft)

        struct FakeHoldRule: RecommendationRule {
            let name = "FakeHold"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .hold, reasoning: "stay put", confidence: 0.7)
            }
        }

        let engine = RecommendationEngine(rules: [FakeHoldRule()])
        let rec = engine.evaluate(
            holding: holding,
            account: account,
            profile: InvestingProfile(),
            quote: nil
        )
        #expect(rec.categoryEnum == .hold)
    }

    // MARK: - Multi-rule aggregation

    @Test func highestConfidenceRuleWinsWhenMultipleFire() async throws {
        let (holding, account) = try makeEverything()

        struct HighConfidenceReduce: RecommendationRule {
            let name = "HighReduce"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .reduce, reasoning: "too big", confidence: 0.85)
            }
        }
        struct LowConfidenceHold: RecommendationRule {
            let name = "LowHold"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .hold, reasoning: "eh", confidence: 0.4)
            }
        }

        let engine = RecommendationEngine(rules: [LowConfidenceHold(), HighConfidenceReduce()])
        let rec = engine.evaluate(
            holding: holding,
            account: account,
            profile: InvestingProfile(),
            quote: nil
        )
        #expect(rec.categoryEnum == .reduce)
        // Primary reasoning is only the winning rule's text — no more
        // string-concatenation of losers.
        #expect(rec.reasoning == "too big")
        #expect(rec.reasoning.contains("Also considered") == false)
        // Loser moves to structured supporting outputs.
        #expect(rec.supportingOutputs.count == 1)
        #expect(rec.supportingOutputs.first?.reasoning == "eh")
        #expect(rec.supportingOutputs.first?.category == .hold)
    }

    @Test func supportingOutputsPopulatedWhenMultipleRulesFire() async throws {
        let (holding, account) = try makeEverything()

        struct RuleA: RecommendationRule {
            let name = "RuleA"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .reduce, reasoning: "A", confidence: 0.9, cautionNote: "careful-A")
            }
        }
        struct RuleB: RecommendationRule {
            let name = "RuleB"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .wait, reasoning: "B", confidence: 0.6, cautionNote: "careful-B")
            }
        }
        struct RuleC: RecommendationRule {
            let name = "RuleC"
            func evaluate(holding: Holding, account: Account, profile: InvestingProfile, quote: QuoteResult?) -> RuleOutput? {
                RuleOutput(ruleName: name, category: .researchMore, reasoning: "C", confidence: 0.3)
            }
        }

        let engine = RecommendationEngine(rules: [RuleC(), RuleA(), RuleB()])
        let rec = engine.evaluate(
            holding: holding,
            account: account,
            profile: InvestingProfile(),
            quote: nil
        )

        // Winner (RuleA) is primary.
        #expect(rec.reasoning == "A")
        #expect(rec.cautionNote == "careful-A")

        // The other two are persisted as structured RecommendationOutputs,
        // ordered by confidence descending (B before C).
        #expect(rec.supportingOutputs.count == 2)
        let first = rec.supportingOutputs.first
        #expect(first?.reasoning == "B")
        #expect(first?.category == .wait)
        #expect(first?.confidence == Decimal(0.6))
        #expect(first?.cautionNote == "careful-B")
    }

    @Test func defaultRulesWireUpFiveRules() async throws {
        let rules = RecommendationEngine.defaultRules()
        #expect(rules.count == 5)
    }
}
