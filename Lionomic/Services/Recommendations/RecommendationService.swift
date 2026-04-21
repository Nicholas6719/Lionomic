import Foundation
import SwiftData
import os

/// Coordinates the recommendation engine with persistence, market data,
/// and alert firing.
///
/// `generate(for:)` runs the engine over every holding in an account,
/// fetching a quote for each non-NFT symbol (cache-first, then network),
/// and persists the results. Before clearing the prior set, it captures
/// a snapshot by symbol so post-run it can fire recommendation-change
/// and holding-risk alerts — gated on the corresponding `AppPreferences`
/// toggles.
@MainActor
final class RecommendationService {

    private let modelContext: ModelContext
    private let marketDataService: MarketDataService
    private let profileRepository: ProfileRepository
    private let preferencesRepository: PreferencesRepository
    private let notificationService: NotificationService
    private let alertRepository: AlertRepository
    private let engine: RecommendationEngine

    init(
        modelContext: ModelContext,
        marketDataService: MarketDataService,
        profileRepository: ProfileRepository,
        preferencesRepository: PreferencesRepository,
        notificationService: NotificationService,
        alertRepository: AlertRepository,
        engine: RecommendationEngine = RecommendationEngine()
    ) {
        self.modelContext          = modelContext
        self.marketDataService     = marketDataService
        self.profileRepository     = profileRepository
        self.preferencesRepository = preferencesRepository
        self.notificationService   = notificationService
        self.alertRepository       = alertRepository
        self.engine                = engine
    }

    /// Regenerate recommendations for every account and return the full
    /// persisted set (sorted by confidence, descending).
    @discardableResult
    func generateAll(accounts: [Account]) async -> [Recommendation] {
        var all: [Recommendation] = []
        for account in accounts {
            let forAccount = await generate(for: account)
            all.append(contentsOf: forAccount)
        }
        return all.sorted { $0.confidence > $1.confidence }
    }

    /// Regenerate recommendations for a single account.
    ///
    /// Order of operations is important:
    ///   1. Snapshot the existing per-symbol category map **before** the
    ///      clear step — otherwise the diff has nothing to compare against.
    ///   2. Clear old recommendations and write the new set.
    ///   3. Fire alerts based on the diff, gated on preferences.
    @discardableResult
    func generate(for account: Account) async -> [Recommendation] {
        let profile = (try? profileRepository.fetchProfile()) ?? InvestingProfile()
        // MProfile: resolve the account-level override once per generate
        // call and feed the merged `EffectiveProfile` into every rule.
        let override = profileRepository.override(for: account)
        let effective = EffectiveProfile.resolve(profile: profile, override: override)

        // Step 1: snapshot before destroy. Map by symbol since holdings
        // can have their IDs change across edits but symbols are stable
        // within an account (enforced by the duplicate-symbol guard).
        let previousByCategory = existingCategoriesBySymbol(accountID: account.id)

        clearExisting(accountID: account.id)

        var generated: [Recommendation] = []
        for holding in account.holdings {
            let quote = await fetchQuote(for: holding)
            let rec = engine.evaluate(
                holding: holding,
                account: account,
                profile: effective,
                quote: quote
            )
            modelContext.insert(rec)
            generated.append(rec)
        }

        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("RecommendationService save failed: \(String(describing: error), privacy: .public)")
        }

        // Step 3: alerts (after the new set is safely on disk).
        await fireAlertsForDiff(newRecs: generated, previous: previousByCategory)

        return generated
    }

    /// Load all persisted recommendations, newest first within each confidence tier.
    func fetchAll() throws -> [Recommendation] {
        let descriptor = FetchDescriptor<Recommendation>(
            sortBy: [
                SortDescriptor(\.confidence, order: .reverse),
                SortDescriptor(\.generatedAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Alerts

    private func fireAlertsForDiff(
        newRecs: [Recommendation],
        previous: [String: RecommendationCategory]
    ) async {
        let prefs = preferencesRepository.currentPreferences
        let changeEnabled = prefs?.recommendationChangeAlertsEnabled ?? false
        let riskEnabled   = prefs?.holdingRiskAlertsEnabled ?? false

        // Short-circuit when both gates are off — no alerts to consider.
        guard changeEnabled || riskEnabled else { return }

        // Pre-fetch the alert history once so holding-risk dedupe doesn't
        // hit the model context per-symbol. Cheap: append-only table, V1
        // volume is tiny.
        let allAlerts = (try? alertRepository.fetchAll()) ?? []
        let now = Date()

        for rec in newRecs {
            // Recommendation-change alert: category differs from prior run.
            if changeEnabled,
               let old = previous[rec.symbol],
               old != rec.categoryEnum {
                await fireRecommendationChangeAlert(
                    symbol: rec.symbol,
                    oldCategory: old,
                    newCategory: rec.categoryEnum,
                    now: now
                )
            }

            // Holding-risk alert: emitted only for `.reduce`, which
            // `OverconcentrationRule` is the sole producer of among the
            // M7 rules. 24-hour dedupe per symbol.
            if riskEnabled, rec.categoryEnum == .reduce,
               !wasRiskAlertFiredWithin24h(symbol: rec.symbol, history: allAlerts, now: now) {
                await fireHoldingRiskAlert(rec: rec, now: now)
            }
        }
    }

    private func fireRecommendationChangeAlert(
        symbol: String,
        oldCategory: RecommendationCategory,
        newCategory: RecommendationCategory,
        now: Date
    ) async {
        let title = "Recommendation changed: \(symbol)"
        let body  = "\(oldCategory.displayName) → \(newCategory.displayName)"
        let identifier = "rec.change.\(symbol)"

        await notificationService.send(title: title, body: body, identifier: identifier)

        let event = AlertEvent(
            kind: .recommendationChange,
            symbol: symbol,
            title: title,
            body: body,
            firedAt: now
        )
        do {
            try alertRepository.add(event)
        } catch {
            Log.persistence.error("Failed to persist recommendationChange AlertEvent: \(String(describing: error), privacy: .public)")
        }
    }

    private func fireHoldingRiskAlert(rec: Recommendation, now: Date) async {
        let title = "Concentration alert: \(rec.symbol)"
        // cautionNote can be empty — fall back to primary reasoning so the
        // notification body is never blank.
        let sourceText = rec.cautionNote.isEmpty ? rec.reasoning : rec.cautionNote
        let body = truncated(sourceText, limit: 150)
        let identifier = "holding.risk.\(rec.symbol)"

        await notificationService.send(title: title, body: body, identifier: identifier)

        let event = AlertEvent(
            kind: .holdingRisk,
            symbol: rec.symbol,
            title: title,
            body: body,
            firedAt: now
        )
        do {
            try alertRepository.add(event)
        } catch {
            Log.persistence.error("Failed to persist holdingRisk AlertEvent: \(String(describing: error), privacy: .public)")
        }
    }

    private func wasRiskAlertFiredWithin24h(
        symbol: String,
        history: [AlertEvent],
        now: Date
    ) -> Bool {
        let cutoff = now.addingTimeInterval(-24 * 3600)
        return history.contains { event in
            event.kindEnum == .holdingRisk
                && event.symbol == symbol
                && event.firedAt > cutoff
        }
    }

    // MARK: - Private

    private func fetchQuote(for holding: Holding) async -> QuoteResult? {
        guard holding.assetType.usesMarketQuote else { return nil }
        if let cached = await marketDataService.cachedQuote(for: holding.symbol), cached.isFresh {
            return cached
        }
        return try? await marketDataService.fetchQuote(symbol: holding.symbol)
    }

    /// Reads the existing recommendations for an account into a
    /// `[symbol: category]` map. Called *before* `clearExisting` so the
    /// post-run diff has a reference point.
    private func existingCategoriesBySymbol(accountID: UUID) -> [String: RecommendationCategory] {
        let descriptor = FetchDescriptor<Recommendation>(
            predicate: #Predicate<Recommendation> { $0.accountID == accountID }
        )
        guard let existing = try? modelContext.fetch(descriptor) else { return [:] }
        var map: [String: RecommendationCategory] = [:]
        for rec in existing {
            map[rec.symbol] = rec.categoryEnum
        }
        return map
    }

    private func clearExisting(accountID: UUID) {
        let descriptor = FetchDescriptor<Recommendation>(
            predicate: #Predicate<Recommendation> { $0.accountID == accountID }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for rec in existing {
                modelContext.delete(rec)
            }
        }
    }

    private func truncated(_ s: String, limit: Int) -> String {
        guard s.count > limit else { return s }
        let end = s.index(s.startIndex, offsetBy: limit)
        return String(s[..<end]) + "…"
    }
}
