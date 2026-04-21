import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Tests for the M9 diff + alert-firing behavior in `RecommendationService`.
/// We exercise the service through in-memory containers and a stub rule so
/// the engine output is deterministic.
@MainActor
struct RecommendationAlertDiffTests {

    // MARK: - Fixtures

    private struct Bundle {
        let service: RecommendationService
        let alerts: AlertRepository
        let prefs: PreferencesRepository
        let portfolio: PortfolioRepository
        let context: ModelContext
    }

    /// A rule whose output is caller-controlled per symbol, so tests can
    /// drive the category for each run without relying on live quotes.
    private final class StubRule: RecommendationRule {
        let name = "Stub"
        var outputsBySymbol: [String: RuleOutput] = [:]

        func evaluate(holding: Holding, account: Account, profile: EffectiveProfile, quote: QuoteResult?) -> RuleOutput? {
            outputsBySymbol[holding.symbol]
        }
    }

    private func makeBundle(stubRule: StubRule) throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)

        let prefs = PreferencesRepository(context: context)
        try prefs.load()
        // Enable both alert toggles — individual tests can flip them off.
        prefs.currentPreferences?.recommendationChangeAlertsEnabled = true
        prefs.currentPreferences?.holdingRiskAlertsEnabled = true
        try context.save()

        let portfolio = PortfolioRepository(modelContext: context)
        let profileRepo = ProfileRepository(modelContext: context)
        _ = try profileRepo.commit(draft: DraftProfile())   // default profile
        let alerts = AlertRepository(modelContext: context)
        let notifications = NotificationService()
        // Stub market data service — not used by the stub rule.
        let market = MarketDataService(modelContainer: container, providers: [])

        let service = RecommendationService(
            modelContext: context,
            marketDataService: market,
            profileRepository: profileRepo,
            preferencesRepository: prefs,
            notificationService: notifications,
            alertRepository: alerts,
            engine: RecommendationEngine(rules: [stubRule])
        )

        return Bundle(
            service: service,
            alerts: alerts,
            prefs: prefs,
            portfolio: portfolio,
            context: context
        )
    }

    private func makeHolding(_ portfolio: PortfolioRepository, account: Account, symbol: String) throws -> Holding {
        try portfolio.commit(draftHolding: DraftHolding(
            accountID: account.id,
            symbol: symbol,
            assetType: .stock,
            shares: 10,
            averageCost: 100
        ))
    }

    // MARK: - Recommendation-change diff

    @Test func firstRunFiresNoChangeAlert() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .hold, reasoning: "r", confidence: 0.6
        )
        _ = await b.service.generate(for: account)

        let events = try b.alerts.fetchAll()
        // No previous run → nothing to diff against.
        #expect(events.filter { $0.kindEnum == .recommendationChange }.isEmpty)
    }

    @Test func categoryChangeFiresAlertWhenEnabled() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        // First run: category = hold
        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .hold, reasoning: "r", confidence: 0.6
        )
        _ = await b.service.generate(for: account)

        // Second run: category = wait → diff fires an alert.
        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .wait, reasoning: "r2", confidence: 0.7
        )
        _ = await b.service.generate(for: account)

        let changes = (try b.alerts.fetchAll()).filter { $0.kindEnum == .recommendationChange }
        #expect(changes.count == 1)
        #expect(changes.first?.symbol == "AAPL")
        #expect(changes.first?.title == "Recommendation changed: AAPL")
        #expect(changes.first?.body == "Hold → Wait")
    }

    @Test func sameCategoryDoesNotFireChangeAlert() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .hold, reasoning: "r", confidence: 0.5
        )
        _ = await b.service.generate(for: account)
        _ = await b.service.generate(for: account)   // identical second run

        let changes = (try b.alerts.fetchAll()).filter { $0.kindEnum == .recommendationChange }
        #expect(changes.isEmpty)
    }

    @Test func changeAlertGatedOffWhenPreferenceDisabled() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        b.prefs.currentPreferences?.recommendationChangeAlertsEnabled = false
        b.prefs.currentPreferences?.holdingRiskAlertsEnabled = false
        try b.context.save()

        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .hold, reasoning: "r", confidence: 0.6
        )
        _ = await b.service.generate(for: account)
        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .wait, reasoning: "r2", confidence: 0.7
        )
        _ = await b.service.generate(for: account)

        let events = try b.alerts.fetchAll()
        #expect(events.isEmpty)   // gated off → no AlertEvent persisted
    }

    // MARK: - Holding-risk alert

    @Test func reduceCategoryFiresHoldingRiskAlert() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .reduce, reasoning: "too big",
            confidence: 0.8, cautionNote: "Trim before tax year end."
        )
        _ = await b.service.generate(for: account)

        let riskEvents = (try b.alerts.fetchAll()).filter { $0.kindEnum == .holdingRisk }
        #expect(riskEvents.count == 1)
        #expect(riskEvents.first?.title == "Concentration alert: AAPL")
        #expect(riskEvents.first?.body.contains("Trim") == true)
    }

    @Test func holdingRiskDedupesWithin24Hours() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .reduce, reasoning: "too big",
            confidence: 0.8, cautionNote: "Trim."
        )

        // Three back-to-back runs with category unchanged.
        _ = await b.service.generate(for: account)
        _ = await b.service.generate(for: account)
        _ = await b.service.generate(for: account)

        let riskEvents = (try b.alerts.fetchAll()).filter { $0.kindEnum == .holdingRisk }
        #expect(riskEvents.count == 1)   // dedupe prevents stacking
    }

    @Test func holdingRiskFiresAgainAfter24h() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .reduce, reasoning: "r",
            confidence: 0.8, cautionNote: "Trim."
        )
        _ = await b.service.generate(for: account)

        // Backdate the existing event so the dedupe window no longer covers it.
        let oldEvent = try b.alerts.fetchAll().first { $0.kindEnum == .holdingRisk }!
        oldEvent.firedAt = Date(timeIntervalSinceNow: -25 * 3600)
        try b.context.save()

        _ = await b.service.generate(for: account)

        let riskEvents = (try b.alerts.fetchAll()).filter { $0.kindEnum == .holdingRisk }
        #expect(riskEvents.count == 2)
    }

    @Test func nonReduceCategoryDoesNotFireHoldingRisk() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        for category in [RecommendationCategory.hold, .wait, .buyNow, .avoid, .researchMore] {
            rule.outputsBySymbol["AAPL"] = RuleOutput(
                ruleName: "Stub", category: category, reasoning: "r",
                confidence: 0.6, cautionNote: "note"
            )
            _ = await b.service.generate(for: account)
        }

        let riskEvents = (try b.alerts.fetchAll()).filter { $0.kindEnum == .holdingRisk }
        #expect(riskEvents.isEmpty)
    }

    @Test func holdingRiskGatedOffWhenPreferenceDisabled() async throws {
        let rule = StubRule()
        let b = try makeBundle(stubRule: rule)
        b.prefs.currentPreferences?.holdingRiskAlertsEnabled = false
        try b.context.save()

        let account = try b.portfolio.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try makeHolding(b.portfolio, account: account, symbol: "AAPL")

        rule.outputsBySymbol["AAPL"] = RuleOutput(
            ruleName: "Stub", category: .reduce, reasoning: "r",
            confidence: 0.8, cautionNote: "Trim."
        )
        _ = await b.service.generate(for: account)

        let riskEvents = (try b.alerts.fetchAll()).filter { $0.kindEnum == .holdingRisk }
        #expect(riskEvents.isEmpty)
    }
}
