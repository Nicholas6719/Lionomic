import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct RecommendationRuleTests {

    // MARK: - Helpers

    private func makeContext() throws -> (ModelContext, PortfolioRepository) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (context, PortfolioRepository(modelContext: context))
    }

    private func makeAccount(
        _ repo: PortfolioRepository,
        kind: AccountKind = .brokerage,
        name: String = "Test"
    ) throws -> Account {
        try repo.commit(draftAccount: DraftAccount(kind: kind, displayName: name))
    }

    private func makeHolding(
        _ repo: PortfolioRepository,
        account: Account,
        symbol: String,
        assetType: AssetType = .stock,
        shares: Decimal? = 10,
        averageCost: Decimal? = 100,
        manualValuation: Decimal? = nil
    ) throws -> Holding {
        try repo.commit(draftHolding: DraftHolding(
            accountID: account.id,
            symbol: symbol,
            assetType: assetType,
            shares: shares,
            averageCost: averageCost,
            manualValuation: manualValuation
        ))
    }

    private func quote(
        symbol: String = "AAPL",
        price: Decimal = 100,
        change: Decimal = 0,
        changePercent: Decimal = 0
    ) -> QuoteResult {
        QuoteResult(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            currency: "USD",
            fetchedAt: Date(),
            providerName: "Test"
        )
    }

    // MARK: - InsufficientDataRule

    @Test func insufficientDataFiresWhenNoQuoteAndNoCost() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        // Create a valid holding, then clear averageCost to simulate the
        // "no quote, no cost" state (the repo validator requires both at commit).
        let holding = try makeHolding(repo, account: account, symbol: "ZZZ", averageCost: 100)
        holding.averageCost = nil

        let rule = InsufficientDataRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(InvestingProfile()),
            quote: nil
        )
        #expect(output != nil)
        #expect(output?.category == .researchMore)
    }

    @Test func insufficientDataDoesNotFireWhenCostPresent() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL", averageCost: 150)
        let rule = InsufficientDataRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(InvestingProfile()),
            quote: nil
        )
        #expect(output == nil)
    }

    @Test func insufficientDataDoesNotFireForNFT() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try repo.commit(draftHolding: DraftHolding(
            accountID: account.id,
            symbol: "BORED",
            assetType: .nft,
            manualValuation: 1000
        ))
        let rule = InsufficientDataRule()
        #expect(rule.evaluate(holding: holding, account: account, profile: .global(InvestingProfile()), quote: nil) == nil)
    }

    // MARK: - OverconcentrationRule

    @Test func overconcentrationFiresWhenBigHoldingExceedsMediumThreshold() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        // Holding A: 10 shares × $100 = $1000 (cost basis)
        _ = try makeHolding(repo, account: account, symbol: "AAA", shares: 10, averageCost: 100)
        // Holding B: 100 shares × $100 = $10000 — much bigger
        let big = try makeHolding(repo, account: account, symbol: "BBB", shares: 100, averageCost: 100)

        let profile = InvestingProfile(concentrationSensitivity: .medium)
        let rule = OverconcentrationRule()
        let output = rule.evaluate(holding: big, account: account, profile: .global(profile), quote: nil)
        #expect(output?.category == .reduce)
        #expect((output?.confidence ?? 0) > 0.6)
    }

    @Test func overconcentrationDoesNotFireWhenBalanced() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        // Two holdings, equal size — each is 50% which is over medium (20%) so it fires.
        // Build a balanced 5-holding account so each is 20% — right at the threshold.
        for i in 1...5 {
            _ = try makeHolding(repo, account: account, symbol: "S\(i)", shares: 10, averageCost: 100)
        }
        let target = account.holdings.first!
        let rule = OverconcentrationRule()
        let output = rule.evaluate(
            holding: target,
            account: account,
            profile: .global(InvestingProfile(concentrationSensitivity: .medium)),
            quote: nil
        )
        // 20% is equal to threshold; rule fires only when > threshold, so we expect nil.
        #expect(output == nil)
    }

    @Test func overconcentrationThresholdAdjustsForLowSensitivity() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        // 4 equal holdings — each is 25%. Low sensitivity threshold is 30%.
        for i in 1...4 {
            _ = try makeHolding(repo, account: account, symbol: "S\(i)", shares: 10, averageCost: 100)
        }
        let target = account.holdings.first!
        let rule = OverconcentrationRule()

        let low = rule.evaluate(
            holding: target,
            account: account,
            profile: .global(InvestingProfile(concentrationSensitivity: .low)),
            quote: nil
        )
        // 25% < 30% — should NOT fire at low sensitivity
        #expect(low == nil)

        let high = rule.evaluate(
            holding: target,
            account: account,
            profile: .global(InvestingProfile(concentrationSensitivity: .high)),
            quote: nil
        )
        // 25% > 15% — should fire at high sensitivity
        #expect(high != nil)
    }

    // MARK: - DipBuyRule

    @Test func dipBuyFiresOnDipWhenEnabled() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let profile = InvestingProfile(preferDipBuying: true, cautionBias: .aggressive)
        let rule = DipBuyRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(profile),
            quote: quote(changePercent: -0.05)   // -5%
        )
        #expect(output?.category == .buyNow)
    }

    @Test func dipBuyReturnsWaitForCautiousBias() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let profile = InvestingProfile(preferDipBuying: true, cautionBias: .cautious)
        let rule = DipBuyRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(profile),
            quote: quote(changePercent: -0.05)
        )
        #expect(output?.category == .wait)
    }

    @Test func dipBuyDoesNotFireWhenDisabled() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let profile = InvestingProfile(preferDipBuying: false)
        let rule = DipBuyRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(profile),
            quote: quote(changePercent: -0.05)
        )
        #expect(output == nil)
    }

    @Test func dipBuyDoesNotFireOnShallowDip() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let profile = InvestingProfile(preferDipBuying: true, cautionBias: .aggressive)
        let rule = DipBuyRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(profile),
            quote: quote(changePercent: -0.01)   // -1%, above threshold
        )
        #expect(output == nil)
    }

    // MARK: - NoChaseRule

    @Test func noChaseFiresOnStrongUpDay() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let rule = NoChaseRule()
        let output = rule.evaluate(
            holding: holding,
            account: account,
            profile: .global(InvestingProfile()),
            quote: quote(changePercent: 0.07)   // +7%
        )
        #expect(output?.category == .wait)
        #expect(output?.cautionNote.isEmpty == false)
    }

    @Test func noChaseDoesNotFireOnFlatOrNegative() async throws {
        let (_, repo) = try makeContext()
        let account = try makeAccount(repo)
        let holding = try makeHolding(repo, account: account, symbol: "AAPL")
        let rule = NoChaseRule()
        let flat = rule.evaluate(
            holding: holding, account: account, profile: .global(InvestingProfile()),
            quote: quote(changePercent: 0)
        )
        let down = rule.evaluate(
            holding: holding, account: account, profile: .global(InvestingProfile()),
            quote: quote(changePercent: -0.02)
        )
        #expect(flat == nil)
        #expect(down == nil)
    }

    // MARK: - RothLongTermBiasRule

    @Test func rothLongTermBiasFiresForRothWithShortHorizon() async throws {
        let (_, repo) = try makeContext()
        let rothAccount = try makeAccount(repo, kind: .rothIRA, name: "My Roth")
        let holding = try makeHolding(repo, account: rothAccount, symbol: "VTI")
        let profile = InvestingProfile(horizonPreference: .short)
        let rule = RothLongTermBiasRule()
        let output = rule.evaluate(
            holding: holding,
            account: rothAccount,
            profile: .global(profile),
            quote: nil
        )
        #expect(output?.category == .hold)
    }

    @Test func rothLongTermBiasDoesNotFireForBrokerage() async throws {
        let (_, repo) = try makeContext()
        let brokerage = try makeAccount(repo, kind: .brokerage)
        let holding = try makeHolding(repo, account: brokerage, symbol: "VTI")
        let profile = InvestingProfile(horizonPreference: .short)
        let rule = RothLongTermBiasRule()
        let output = rule.evaluate(
            holding: holding,
            account: brokerage,
            profile: .global(profile),
            quote: nil
        )
        #expect(output == nil)
    }

    @Test func rothLongTermBiasDoesNotFireForLongHorizon() async throws {
        let (_, repo) = try makeContext()
        let rothAccount = try makeAccount(repo, kind: .rothIRA)
        let holding = try makeHolding(repo, account: rothAccount, symbol: "VTI")
        let profile = InvestingProfile(horizonPreference: .long)
        let rule = RothLongTermBiasRule()
        let output = rule.evaluate(
            holding: holding,
            account: rothAccount,
            profile: .global(profile),
            quote: nil
        )
        #expect(output == nil)
    }
}
