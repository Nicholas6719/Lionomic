import Foundation
import BackgroundTasks
import os

/// Thin wrapper that owns the BGAppRefreshTask registration and scheduling
/// for the Morning Brief. Kept separate from `MorningBriefService` so the
/// service stays trivially testable (no BGTaskScheduler reference).
@MainActor
enum MorningBriefBackgroundTask {

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in `Lionomic-Info.plist`.
    static let identifier = MorningBriefService.bgTaskIdentifier

    /// Register the task handler. **Must be called before
    /// `applicationDidFinishLaunching` returns** — i.e. from `App.init`,
    /// not `.task`. We capture `env` in the handler closure so the task
    /// has everything it needs to generate a brief.
    static func register(env: AppEnvironment) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: identifier,
            using: nil
        ) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            Task { @MainActor in
                await handle(refresh: refresh, env: env)
            }
        }
    }

    /// Schedule the next refresh for tomorrow at 07:00 device local time.
    /// Safe to call repeatedly — `submit(_:)` replaces any pending request
    /// with the same identifier.
    static func scheduleNext(now: Date = .now, calendar: Calendar = .current) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = nextSevenAM(after: now, calendar: calendar)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            // Common failure modes: running on simulator (unsupported), or
            // the identifier missing from Info.plist. Neither should crash
            // the app — the user still gets manual refresh.
            Log.app.error("BGAppRefreshTask submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Handler

    private static func handle(refresh: BGAppRefreshTask, env: AppEnvironment) async {
        // Always reschedule first so a chain-breaking crash still tries
        // again tomorrow.
        scheduleNext()

        // Cooperatively cancel on system expiration.
        let workItem = Task {
            await generateAndNotify(env: env)
        }
        refresh.expirationHandler = {
            workItem.cancel()
        }

        await workItem.value
        refresh.setTaskCompleted(success: !workItem.isCancelled)
    }

    private static func generateAndNotify(env: AppEnvironment) async {
        let accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
        let profile = (try? env.profileRepository.fetchProfile()) ?? InvestingProfile()
        let recs = await env.recommendationService.generateAll(accounts: accounts)

        var quotes: [String: QuoteResult] = [:]
        for symbol in Set(accounts.flatMap { $0.holdings }.filter { $0.assetType.usesMarketQuote }.map(\.symbol)) {
            if let cached = await env.marketDataService.cachedQuote(for: symbol) {
                quotes[symbol] = cached
            }
        }

        let brief = env.morningBriefService.generateBrief(
            accounts: accounts,
            profile: profile,
            quotes: quotes,
            recommendations: recs
        )
        await env.morningBriefService.postMorningBriefNotification(brief)
    }

    // MARK: - Helpers

    static func nextSevenAM(after reference: Date, calendar: Calendar = .current) -> Date {
        var components = calendar.dateComponents([.year, .month, .day], from: reference)
        components.hour = 7
        components.minute = 0
        components.second = 0
        let today = calendar.date(from: components) ?? reference
        if today > reference {
            return today
        }
        return calendar.date(byAdding: .day, value: 1, to: today) ?? reference.addingTimeInterval(24 * 3600)
    }
}
