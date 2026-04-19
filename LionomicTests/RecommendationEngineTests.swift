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
        // Loser gets appended to supporting reasoning.
        #expect(rec.reasoning.contains("Also considered"))
        #expect(rec.reasoning.contains("eh"))
    }

    @Test func defaultRulesWireUpFiveRules() async throws {
        let rules = RecommendationEngine.defaultRules()
        #expect(rules.count == 5)
    }
}
