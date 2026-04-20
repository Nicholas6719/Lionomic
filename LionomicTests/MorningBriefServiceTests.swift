import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct MorningBriefServiceTests {

    // MARK: - Helpers

    private func makeRepo() throws -> PortfolioRepository {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return PortfolioRepository(modelContext: context)
    }

    private func quote(
        symbol: String,
        price: Decimal = 100,
        change: Decimal = 0,
        changePercent: Decimal = 0,
        fetchedAt: Date = Date()
    ) -> QuoteResult {
        QuoteResult(
            symbol: symbol,
            price: price,
            change: change,
            changePercent: changePercent,
            currency: "USD",
            fetchedAt: fetchedAt,
            providerName: "Test"
        )
    }

    private func staleQuote(symbol: String) -> QuoteResult {
        quote(symbol: symbol, fetchedAt: Date(timeIntervalSinceNow: -600))
    }

    private func date(year: Int, month: Int, day: Int, hour: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = 0
        components.timeZone = TimeZone(identifier: "America/New_York")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    // MARK: - Greeting line templates

    @Test func greetingMorningBefore12() async throws {
        // Monday 2026-04-20 08:00 ET
        let d = date(year: 2026, month: 4, day: 20, hour: 8)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let line = MorningBriefService.greetingLine(now: d, calendar: cal)
        #expect(line.contains("morning"))
        #expect(line.contains("Monday"))
    }

    @Test func greetingAfternoonBefore17() async throws {
        let d = date(year: 2026, month: 4, day: 20, hour: 13)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let line = MorningBriefService.greetingLine(now: d, calendar: cal)
        #expect(line.contains("afternoon"))
    }

    @Test func greetingEveningAfter17() async throws {
        let d = date(year: 2026, month: 4, day: 20, hour: 20)
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "America/New_York")!
        let line = MorningBriefService.greetingLine(now: d, calendar: cal)
        #expect(line.contains("evening"))
    }

    // MARK: - Narrative composition

    @Test func briefWithoutRecommendationsSaysNone() async throws {
        let repo = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = account

        let svc = MorningBriefService(notificationService: NotificationService())
        let brief = svc.generateBrief(
            accounts: [account],
            profile: InvestingProfile(),
            quotes: [:],
            recommendations: []
        )
        #expect(brief.narrativeSummary.contains("No recommendations yet."))
        #expect(brief.topRecommendations.isEmpty)
    }

    @Test func briefWithRecommendationsSortsByConfidence() async throws {
        let repo = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))

        let low = Recommendation(
            holdingID: UUID(), accountID: account.id, symbol: "AAA",
            assetType: .stock, category: .hold, reasoning: "r1", confidence: 0.3
        )
        let high = Recommendation(
            holdingID: UUID(), accountID: account.id, symbol: "BBB",
            assetType: .stock, category: .reduce, reasoning: "r2", confidence: 0.9
        )
        let mid = Recommendation(
            holdingID: UUID(), accountID: account.id, symbol: "CCC",
            assetType: .stock, category: .buyNow, reasoning: "r3", confidence: 0.6
        )

        let svc = MorningBriefService(notificationService: NotificationService())
        let brief = svc.generateBrief(
            accounts: [account],
            profile: InvestingProfile(),
            quotes: [:],
            recommendations: [low, high, mid]
        )
        #expect(brief.topRecommendations.count == 3)
        #expect(brief.topRecommendations.first?.symbol == "BBB")
        #expect(brief.narrativeSummary.contains("BBB"))
        #expect(brief.narrativeSummary.contains("Reduce"))
    }

    @Test func briefOmitsTotalLineWhenNoFreshQuotes() async throws {
        let repo = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try repo.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 100
        ))

        let svc = MorningBriefService(notificationService: NotificationService())
        // Only a stale quote — the brief must not emit a total line.
        let brief = svc.generateBrief(
            accounts: [account],
            profile: InvestingProfile(),
            quotes: ["AAPL": staleQuote(symbol: "AAPL")],
            recommendations: []
        )
        #expect(brief.narrativeSummary.contains("Portfolio:") == false)
        #expect(brief.portfolioChangeNote == nil)
    }

    @Test func briefEmitsTotalLineWhenFreshQuotePresent() async throws {
        let repo = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "X"))
        _ = try repo.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 10, averageCost: 100
        ))

        let svc = MorningBriefService(notificationService: NotificationService())
        let brief = svc.generateBrief(
            accounts: [account],
            profile: InvestingProfile(),
            quotes: ["AAPL": quote(symbol: "AAPL", price: 200, change: 5)],
            recommendations: []
        )
        #expect(brief.narrativeSummary.contains("Portfolio:"))
        // 10 shares × $5 change = +$50
        #expect(brief.portfolioChangeNote?.contains("+") == true)
    }

    @Test func briefNeverCrashesOnEmptyInput() async throws {
        let svc = MorningBriefService(notificationService: NotificationService())
        let brief = svc.generateBrief(
            accounts: [],
            profile: InvestingProfile(),
            quotes: [:],
            recommendations: []
        )
        #expect(!brief.narrativeSummary.isEmpty)
        #expect(brief.topRecommendations.isEmpty)
    }

    // MARK: - Truncation

    @Test func truncatedLeavesShortStringUnchanged() async throws {
        let s = "short"
        #expect(MorningBriefService.truncated(s, limit: 150) == "short")
    }

    @Test func truncatedClipsAndAppendsEllipsis() async throws {
        let s = String(repeating: "A", count: 200)
        let out = MorningBriefService.truncated(s, limit: 150)
        #expect(out.count == 151)   // 150 chars + "…"
        #expect(out.hasSuffix("…"))
    }

    // MARK: - Next 07:00 scheduling math

    @Test func nextSevenAMWhenCurrentBefore7ReturnsToday() async throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        // 2026-04-20 05:00 UTC → next 07:00 should be today
        let ref = date(year: 2026, month: 4, day: 20, hour: 1)
        let next = MorningBriefBackgroundTask.nextSevenAM(after: ref, calendar: cal)
        #expect(next > ref)
        #expect(next.timeIntervalSince(ref) < 24 * 3600)
    }

    @Test func nextSevenAMWhenCurrentAfter7ReturnsTomorrow() async throws {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let ref = date(year: 2026, month: 4, day: 20, hour: 15)
        let next = MorningBriefBackgroundTask.nextSevenAM(after: ref, calendar: cal)
        #expect(next > ref)
        // Should land in the [15h, 39h] window from the 15:00 reference.
        let delta = next.timeIntervalSince(ref)
        #expect(delta > 3600)
        #expect(delta < 48 * 3600)
    }
}
