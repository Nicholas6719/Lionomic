import Foundation
import SwiftData
import BackgroundTasks
import os

/// Background `BGAppRefreshTask` that pulls fresh quotes for every symbol
/// carrying at least one active price-alert threshold (either on a
/// `Holding` or a `WatchlistItem`) and feeds each quote through
/// `AlertFiringCoordinator` — the same coordinator used by the foreground
/// quote-refresh path. Designed to run briefly (iOS caps BGAppRefreshTask
/// at a small wall-clock budget), so the work is tightly scoped:
///   1. Collect de-duplicated symbols with active thresholds.
///   2. Fetch a quote for each (cache-first; the actor honors the 60s
///      freshness window).
///   3. Let `MarketDataService.onQuoteUpdated` fire the alert check.
///
/// Kept separate from `MorningBriefBackgroundTask` so the two features
/// can evolve (and fail) independently.
@MainActor
enum BackgroundAlertTask {

    /// Must match `BGTaskSchedulerPermittedIdentifiers` in `Lionomic-Info.plist`.
    /// Diverges from the project's bundle-ID-prefixed convention by design
    /// (spec-chosen identifier — works on modern iOS but flagged in the
    /// report as a future-cleanup candidate).
    static let identifier = "com.lionomic.backgroundAlerts"

    /// Soonest the scheduler should fire again. 15 minutes is well below
    /// typical iOS throttling (which often stretches to 30–60 min in
    /// practice) while giving threshold crossings a reasonably prompt
    /// first-look.
    private static let earliestBeginInterval: TimeInterval = 15 * 60

    // MARK: - Registration

    /// Must be called before `applicationDidFinishLaunching` returns.
    /// Mirrors the pattern established by `MorningBriefBackgroundTask`.
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

    // MARK: - Scheduling

    /// Submit a new `BGAppRefreshTaskRequest`. Safe to call repeatedly —
    /// the scheduler replaces any pending request with the same identifier.
    /// Common failure modes (simulator, missing plist entry) are logged
    /// rather than crashed, matching `MorningBriefBackgroundTask`.
    static func scheduleNext(now: Date = .now) {
        let request = BGAppRefreshTaskRequest(identifier: identifier)
        request.earliestBeginDate = now.addingTimeInterval(earliestBeginInterval)
        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            Log.app.error("BackgroundAlertTask submit failed: \(String(describing: error), privacy: .public)")
        }
    }

    // MARK: - Run (callable directly for tests / future foreground triggers)

    /// The public entry point that does the actual work. Called from
    /// `handle(refresh:env:)` inside the BGTask handler. Extracted so
    /// tests can exercise the symbol-collection and quote-dispatch logic
    /// without spinning up a real `BGAppRefreshTask`.
    ///
    /// Returns `true` when the run completed without being cancelled.
    /// Failure to fetch any individual quote is swallowed — we want
    /// partial progress rather than a global abort.
    @discardableResult
    static func run(appEnvironment env: AppEnvironment) async -> Bool {
        // Short-circuit when neither alert category is enabled — no point
        // hitting the network.
        let prefs = env.preferencesRepository.currentPreferences
        let priceOn = prefs?.priceAlertsEnabled == true
        let watchOn = prefs?.watchlistAlertsEnabled == true
        guard priceOn || watchOn else { return true }

        let symbols = collectAlertSymbols(
            modelContext: env.modelContainer.mainContext,
            includeHoldings: priceOn,
            includeWatchlist: watchOn
        )
        guard !symbols.isEmpty else { return true }

        for symbol in symbols {
            if Task.isCancelled { return false }
            // `fetchQuote` invokes `upsert` → the `onQuoteUpdated` hook
            // wired in `AppEnvironment.init` runs `AlertFiringCoordinator.
            // handleQuoteUpdate(...)`. No need to call the coordinator
            // directly here — the hook is the single canonical path.
            _ = try? await env.marketDataService.fetchQuote(symbol: symbol)
        }
        return !Task.isCancelled
    }

    // MARK: - Symbol collection

    /// Unions the distinct symbols carrying at least one non-nil alert
    /// threshold across `Holding` and `WatchlistItem`. `includeHoldings`
    /// / `includeWatchlist` let callers skip one side when the matching
    /// pref toggle is off.
    ///
    /// Runs on whatever actor called it — it reads a `ModelContext` the
    /// caller supplies, so the BGTask path uses `mainContext` (same as
    /// `AlertFiringCoordinator`).
    static func collectAlertSymbols(
        modelContext: ModelContext,
        includeHoldings: Bool,
        includeWatchlist: Bool
    ) -> [String] {
        var symbols: Set<String> = []

        if includeHoldings {
            let descriptor = FetchDescriptor<Holding>(
                predicate: #Predicate<Holding> {
                    $0.alertAbovePrice != nil || $0.alertBelowPrice != nil
                }
            )
            if let holdings = try? modelContext.fetch(descriptor) {
                for h in holdings where h.assetType.usesMarketQuote {
                    symbols.insert(h.symbol)
                }
            }
        }

        if includeWatchlist {
            let descriptor = FetchDescriptor<WatchlistItem>(
                predicate: #Predicate<WatchlistItem> {
                    $0.alertAbovePrice != nil || $0.alertBelowPrice != nil
                }
            )
            if let items = try? modelContext.fetch(descriptor) {
                for item in items where item.assetType.usesMarketQuote {
                    symbols.insert(item.symbol)
                }
            }
        }

        // Deterministic ordering so BGTask execution is reproducible.
        return symbols.sorted()
    }

    // MARK: - Handler

    private static func handle(refresh: BGAppRefreshTask, env: AppEnvironment) async {
        // Always reschedule first — matches MorningBriefBackgroundTask so
        // a crash mid-handler still leaves a pending request for next time.
        scheduleNext()

        let workItem = Task {
            await run(appEnvironment: env)
        }
        refresh.expirationHandler = {
            workItem.cancel()
        }
        let success = await workItem.value
        refresh.setTaskCompleted(success: success && !workItem.isCancelled)
    }
}
