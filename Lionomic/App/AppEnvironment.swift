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
    let historyService: HistoryService
    let marketDataService: MarketDataService
    let recommendationService: RecommendationService
    let keychainService = KeychainService()
    let biometricService = BiometricService()

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.profileRepository = ProfileRepository(modelContext: context)
        self.portfolioRepository = PortfolioRepository(modelContext: context)
        self.watchlistRepository = WatchlistRepository(modelContext: context)
        self.preferencesRepository = PreferencesRepository(context: context)
        self.historyService = HistoryService(context: context)
        self.marketDataService = MarketDataService(
            modelContainer: modelContainer,
            keychain: keychainService
        )
        self.recommendationService = RecommendationService(
            modelContext: context,
            marketDataService: self.marketDataService,
            profileRepository: self.profileRepository
        )
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
