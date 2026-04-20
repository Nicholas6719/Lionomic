import Foundation
import SwiftData
import os

@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let profileRepository: ProfileRepository
    let portfolioRepository: PortfolioRepository
    let watchlistRepository: WatchlistRepository
    let preferencesRepository: PreferencesRepository
    let alertRepository: AlertRepository
    let historyService: HistoryService
    let marketDataService: MarketDataService
    let recommendationService: RecommendationService
    let morningBriefService: MorningBriefService
    let notificationService: NotificationService
    /// M10 scaffold wiring: always `NoopAIService` in V1. The swap to
    /// `AnthropicAIService(apiKey:)` happens here and nowhere else once
    /// the concrete implementation lands.
    let aiService: any AIService
    let keychainService = KeychainService()
    let biometricService = BiometricService()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.profileRepository = ProfileRepository(modelContext: context)
        self.portfolioRepository = PortfolioRepository(modelContext: context)
        self.watchlistRepository = WatchlistRepository(modelContext: context)
        self.preferencesRepository = PreferencesRepository(context: context)
        self.alertRepository = AlertRepository(modelContext: context)
        self.historyService = HistoryService(context: context)
        self.marketDataService = MarketDataService(
            modelContainer: modelContainer,
            keychain: keychainService
        )
        self.notificationService = NotificationService()
        self.recommendationService = RecommendationService(
            modelContext: context,
            marketDataService: self.marketDataService,
            profileRepository: self.profileRepository,
            preferencesRepository: self.preferencesRepository,
            notificationService: self.notificationService,
            alertRepository: self.alertRepository
        )
        self.morningBriefService = MorningBriefService(
            notificationService: self.notificationService
        )
        self.aiService = NoopAIService()
    }

    func seedOnFirstLaunch() {
        do {
            try watchlistRepository.seedDefaultsIfNeeded()
        } catch {
            Log.persistence.error("Failed to seed default watchlists: \(String(describing: error), privacy: .public)")
        }
        do {
            try preferencesRepository.load()
        } catch {
            Log.persistence.error("Failed to load app preferences: \(String(describing: error), privacy: .public)")
        }
    }

    /// Wipes all user-entered and cached data, then flips `firstLaunchComplete`
    /// back to false so `RootView` re-presents onboarding on next render.
    ///
    /// Preserved: the `InvestingProfile` and the `AppPreferences` row itself —
    /// the preferences row is reused, only its `firstLaunchComplete` is reset.
    ///
    /// After this runs, the user is returned to onboarding. Seeding rebuilds
    /// the two default watchlists the first time `seedOnFirstLaunch()` fires
    /// again; `seedDefaultsIfNeeded` is idempotent.
    func resetAllData() {
        let context = modelContainer.mainContext
        wipe(Account.self,           in: context)
        wipe(Holding.self,           in: context)
        wipe(WatchlistItem.self,     in: context)
        wipe(Watchlist.self,         in: context)   // seed re-creates defaults on next launch
        wipe(ContributionEvent.self, in: context)
        wipe(HoldingSnapshot.self,   in: context)
        wipe(AccountSnapshot.self,   in: context)
        wipe(CachedQuote.self,       in: context)
        wipe(Recommendation.self,    in: context)
        wipe(AlertEvent.self,        in: context)

        // Drop any pending/delivered notifications — a data reset shouldn't
        // leave stale alerts sitting in Notification Center.
        notificationService.cancelAll()

        preferencesRepository.currentPreferences?.firstLaunchComplete = false
        preferencesRepository.currentPreferences?.updatedAt = Date()

        do {
            try context.save()
        } catch {
            Log.persistence.error("resetAllData save failed: \(String(describing: error), privacy: .public)")
        }

        // Re-seed watchlists so the user lands on a clean baseline (not blank).
        do {
            try watchlistRepository.seedDefaultsIfNeeded()
        } catch {
            Log.persistence.error("re-seed after reset failed: \(String(describing: error), privacy: .public)")
        }
    }

    private func wipe<T: PersistentModel>(_ type: T.Type, in context: ModelContext) {
        do {
            let all = try context.fetch(FetchDescriptor<T>())
            for row in all { context.delete(row) }
        } catch {
            Log.persistence.error("wipe \(String(describing: type), privacy: .public) failed: \(String(describing: error), privacy: .public)")
        }
    }
}
