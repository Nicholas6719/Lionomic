import Foundation
import os

/// Generates `MorningBrief` values from passed-in model objects and owns
/// the narrow notification integration for the Morning Brief feature.
/// No SwiftData dependency — the service consumes whatever the caller
/// hands it, which keeps it trivially testable.
///
/// All UNUserNotificationCenter access goes through `NotificationService`
/// (M9 consolidation). This class no longer touches `UserNotifications`
/// directly.
@MainActor
final class MorningBriefService {

    private let notificationService: NotificationService

    init(notificationService: NotificationService) {
        self.notificationService = notificationService
    }

    /// Pure, synchronous. No I/O. Safe to call from BGTask handlers,
    /// view `.task` closures, and tests.
    ///
    /// Spec deviation carried from M8: `Recommendation` objects don't
    /// live on `Account`, so a `recommendations:` parameter supplies the
    /// pool that `topRecommendations` draws from. Defaults to `[]` so
    /// callers without recommendations still get a valid brief.
    func generateBrief(
        accounts: [Account],
        profile: InvestingProfile,
        quotes: [String: QuoteResult],
        recommendations: [Recommendation] = [],
        at now: Date = .now,
        calendar: Calendar = .current
    ) -> MorningBrief {

        // Line 1: total portfolio value when we have any fresh quotes.
        let freshTotalLine = Self.freshTotalLine(accounts: accounts, quotes: quotes)

        // Top pick sorted across every persisted recommendation.
        let top = Array(
            recommendations.sorted { $0.confidence > $1.confidence }.prefix(3)
        )

        // Line 2: "Top pick: …" or "No recommendations yet."
        let topPickLine: String
        if let winner = top.first {
            topPickLine = "Top pick: \(winner.symbol) — \(winner.categoryEnum.displayName)"
        } else {
            topPickLine = "No recommendations yet."
        }

        // Line 3: greeting keyed on the device calendar's hour + weekday.
        let greetingLine = Self.greetingLine(now: now, calendar: calendar)

        let narrative = [freshTotalLine, topPickLine, greetingLine]
            .compactMap { $0 }
            .joined(separator: "\n")

        return MorningBrief(
            narrativeSummary: narrative,
            portfolioChangeNote: Self.changeNote(accounts: accounts, quotes: quotes),
            topRecommendations: top,
            generatedAt: now
        )
    }

    // MARK: - Notifications

    /// Lazy auth request. Forwards to `NotificationService`; kept on this
    /// type so the BGTask handler and card view don't need to know about
    /// the notification plumbing.
    func requestNotificationAuthorizationIfNeeded() async {
        await notificationService.requestAuthorization()
    }

    /// Posts (or replaces) the daily morning-brief notification. The
    /// stable identifier means repeat fires overwrite instead of stacking.
    func postMorningBriefNotification(_ brief: MorningBrief) async {
        await notificationService.send(
            title: "Lionomic Morning Brief",
            body: Self.truncated(brief.narrativeSummary, limit: 150),
            identifier: Self.notificationIdentifier
        )
    }

    // MARK: - Constants

    /// Matches `BGTaskSchedulerPermittedIdentifiers` in `Lionomic-Info.plist`.
    /// Any mismatch crashes the app at `BGTaskScheduler.register` time.
    static let bgTaskIdentifier = "Coppola.Lionomic.morningbrief"

    /// Replacing-identifier for the daily notification — re-posting with
    /// the same identifier replaces any pending duplicate.
    static let notificationIdentifier = "morningbrief.daily"

    // MARK: - Template helpers (static so they're trivially testable)

    static func greetingLine(now: Date, calendar: Calendar = .current) -> String {
        let hour = calendar.component(.hour, from: now)
        let part: String
        switch hour {
        case ..<12:  part = "morning"
        case ..<17:  part = "afternoon"
        default:     part = "evening"
        }
        let weekday = now.formatted(.dateTime.weekday(.wide))
        return "Have a good \(part) — \(weekday)."
    }

    static func truncated(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        let end = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<end]) + "…"
    }

    // MARK: - Private helpers

    /// Only emits a value line when at least one non-NFT holding has a
    /// fresh quote. Otherwise omit — better silent than a stale number.
    private static func freshTotalLine(
        accounts: [Account],
        quotes: [String: QuoteResult]
    ) -> String? {
        let symbols = accounts.flatMap { $0.holdings }
            .filter { $0.assetType.usesMarketQuote }
            .map(\.symbol)
        guard symbols.contains(where: { quotes[$0]?.isFresh == true }) else { return nil }

        let totals = PortfolioValuation.totals(for: accounts, quoteFor: {
            guard let q = quotes[$0], q.isFresh else { return nil }
            return q
        })
        return "Portfolio: \(MoneyFormatter.string(from: totals.total))"
    }

    /// Aggregate **intraday** absolute dollar change across non-NFT
    /// holdings with fresh quotes. Derived from `QuoteResult.change` — the
    /// provider's session delta — so it reflects today's move only. This
    /// is **not** an unrealized gain/loss (no cost-basis comparison) and
    /// **not** a historical delta (no `HoldingSnapshot` usage). Returns
    /// `nil` when no holding has a fresh quote — better silent than a
    /// stale or misleading number.
    private static func changeNote(
        accounts: [Account],
        quotes: [String: QuoteResult]
    ) -> String? {
        let holdings = accounts.flatMap { $0.holdings }
        var totalIntradayChange: Decimal = 0
        var touched = false
        for h in holdings where h.assetType.usesMarketQuote {
            guard let shares = h.shares, let q = quotes[h.symbol], q.isFresh else { continue }
            totalIntradayChange += shares * q.change
            touched = true
        }
        guard touched else { return nil }
        return "Today's change: \(MoneyFormatter.signedString(from: totalIntradayChange))"
    }
}
