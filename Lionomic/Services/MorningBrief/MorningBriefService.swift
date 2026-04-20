import Foundation
import UserNotifications
import os

/// Generates `MorningBrief` values from passed-in model objects and owns
/// the narrow notification/BGTask integration for the M8 Morning Brief
/// feature. No SwiftData dependency — the service consumes whatever the
/// caller hands it, which keeps it trivially testable.
///
/// Notification scope is intentionally limited: we do not build a full
/// `NotificationService` here (that arrives in M9). This type exposes
/// only what the Morning Brief pipeline needs.
@MainActor
final class MorningBriefService {

    /// Pure, synchronous. No I/O. Safe to call from BGTask handlers,
    /// view `.task` closures, and tests.
    ///
    /// Spec deviation: `Recommendation` objects don't live on `Account`,
    /// so a fourth `recommendations:` parameter was added to supply the
    /// pool that `topRecommendations` draws from. Defaults to `[]` so
    /// callers without recommendations yet still get a valid brief.
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

    /// Requests `.alert + .sound` authorization only if the system has
    /// never decided (`.notDetermined`). Call sites should always use
    /// this — we never silently re-prompt.
    func requestNotificationAuthorizationIfNeeded() async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.app.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
        }
    }

    /// Posts (or replaces) the daily morning-brief notification. Uses a
    /// stable identifier so repeat fires overwrite instead of stacking.
    /// Silent no-op when the user hasn't authorized — never re-prompts.
    func postMorningBriefNotification(_ brief: MorningBrief) async {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized || settings.authorizationStatus == .provisional else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Lionomic Morning Brief"
        content.body  = Self.truncated(brief.narrativeSummary, limit: 150)
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: Self.notificationIdentifier,
            content: content,
            trigger: nil
        )
        do {
            try await center.add(request)
        } catch {
            Log.app.error("Morning brief notification post failed: \(String(describing: error), privacy: .public)")
        }
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

    /// Aggregate day-change note across holdings that have fresh quotes.
    /// `nil` when there's nothing to say.
    private static func changeNote(
        accounts: [Account],
        quotes: [String: QuoteResult]
    ) -> String? {
        let holdings = accounts.flatMap { $0.holdings }
        var totalChange: Decimal = 0
        var touched = false
        for h in holdings where h.assetType.usesMarketQuote {
            guard let shares = h.shares, let q = quotes[h.symbol], q.isFresh else { continue }
            totalChange += shares * q.change
            touched = true
        }
        guard touched else { return nil }
        return "Today's move: \(MoneyFormatter.signedString(from: totalChange))"
    }

}
