import Foundation
import SwiftData

// MARK: - DraftPreferences

/// A value-type snapshot of all app preferences.
/// Build one, show a review sheet, then call `PreferencesRepository.commit(draft:)`.
struct DraftPreferences: Hashable {

    var morningBriefHour: Int
    var morningBriefMinute: Int
    var quoteRefreshCadenceMinutes: Int
    var biometricsEnabled: Bool
    var contextualHelpEnabled: Bool

    var priceAlertsEnabled: Bool
    var watchlistAlertsEnabled: Bool
    var holdingRiskAlertsEnabled: Bool
    var recommendationChangeAlertsEnabled: Bool

    /// Edit flow — pre-populates from existing record.
    init(editing prefs: AppPreferences) {
        morningBriefHour                  = prefs.morningBriefHour
        morningBriefMinute                = prefs.morningBriefMinute
        quoteRefreshCadenceMinutes        = prefs.quoteRefreshCadenceMinutes
        biometricsEnabled                 = prefs.biometricsEnabled
        contextualHelpEnabled             = prefs.contextualHelpEnabled
        priceAlertsEnabled                = prefs.priceAlertsEnabled
        watchlistAlertsEnabled            = prefs.watchlistAlertsEnabled
        holdingRiskAlertsEnabled          = prefs.holdingRiskAlertsEnabled
        recommendationChangeAlertsEnabled = prefs.recommendationChangeAlertsEnabled
    }

    /// First-run defaults.
    ///
    /// **All seven defaults below must stay in sync with the
    /// `AppPreferences` model initializer.** That model is the canonical
    /// source of first-launch state because `PreferencesRepository.load()`
    /// creates the record via `AppPreferences()`, never via this Draft
    /// initializer. Any drift is silent but observable — users would see
    /// editor values that were never actually applied at launch. Covered
    /// here: `morningBriefHour` / `morningBriefMinute` /
    /// `quoteRefreshCadenceMinutes` plus the four alert bools. The two
    /// remaining fields (`biometricsEnabled`, `contextualHelpEnabled`)
    /// already match the model and don't need special attention.
    init() {
        morningBriefHour                  = 7
        morningBriefMinute                = 15
        quoteRefreshCadenceMinutes        = 5
        biometricsEnabled                 = true
        contextualHelpEnabled             = true
        priceAlertsEnabled                = false
        watchlistAlertsEnabled            = false
        holdingRiskAlertsEnabled          = false
        recommendationChangeAlertsEnabled = false
    }
}

// MARK: - PreferencesRepository

/// Wraps the single `AppPreferences` record.
///
/// Always exactly one record. `load()` creates it with defaults on first install.
/// All changes go through `commit(draft:)` after a user review step.
///
/// Not `@Observable`: `AppPreferences` is a SwiftData `@Model`, which is already
/// observable on its stored properties. Views read
/// `env.preferencesRepository.currentPreferences?.biometricsEnabled` and SwiftData
/// tracks that model's change notifications for them.
@MainActor
final class PreferencesRepository {

    private(set) var currentPreferences: AppPreferences?
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    /// Fetches or creates the single preferences record.
    /// Call once from `AppEnvironment.seedOnFirstLaunch()`.
    func load() throws {
        let results = try context.fetch(FetchDescriptor<AppPreferences>())
        if let existing = results.first {
            currentPreferences = existing
        } else {
            let defaults = AppPreferences()
            context.insert(defaults)
            try context.save()
            currentPreferences = defaults
        }
    }

    /// Flips the `firstLaunchComplete` flag after onboarding is confirmed.
    /// Not user data; not routed through draft/review. Loads the record if needed.
    func markFirstLaunchComplete() throws {
        if currentPreferences == nil { try load() }
        currentPreferences?.firstLaunchComplete = true
        currentPreferences?.updatedAt = Date()
        try context.save()
    }

    /// Applies a reviewed draft. Only call after user confirmation.
    func commit(draft: DraftPreferences) throws {
        let prefs: AppPreferences
        if let existing = currentPreferences {
            prefs = existing
        } else {
            let fresh = AppPreferences()
            context.insert(fresh)
            prefs = fresh
        }

        prefs.morningBriefHour                  = draft.morningBriefHour
        prefs.morningBriefMinute                = draft.morningBriefMinute
        prefs.quoteRefreshCadenceMinutes        = draft.quoteRefreshCadenceMinutes
        prefs.biometricsEnabled                 = draft.biometricsEnabled
        prefs.contextualHelpEnabled             = draft.contextualHelpEnabled
        prefs.priceAlertsEnabled                = draft.priceAlertsEnabled
        prefs.watchlistAlertsEnabled            = draft.watchlistAlertsEnabled
        prefs.holdingRiskAlertsEnabled          = draft.holdingRiskAlertsEnabled
        prefs.recommendationChangeAlertsEnabled = draft.recommendationChangeAlertsEnabled
        prefs.updatedAt                         = Date()

        try context.save()
        currentPreferences = prefs
    }
}
