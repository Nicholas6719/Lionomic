import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct SettingsEditingTests {

    // MARK: - Helpers

    /// Builds an `AppEnvironment` over an in-memory container so we can exercise
    /// the real `resetAllData()` path without touching disk. Seed + load are run
    /// the same way the production app does on first launch.
    private func makeEnv() throws -> AppEnvironment {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let env = AppEnvironment(modelContainer: container)
        env.seedOnFirstLaunch()
        return env
    }

    // MARK: - Profile editing

    @Test("EditProfileView commit updates the stored profile")
    func profileCommitUpdatesStoredRecord() throws {
        let env = try makeEnv()

        var draft = DraftProfile()
        draft.riskTolerance         = .aggressive
        draft.horizonPreference     = .long
        draft.concentrationSensitivity = .low
        draft.cautionBias           = .aggressive
        draft.preferDipBuying       = true

        _ = try env.profileRepository.commit(draft: draft)

        let stored = try env.profileRepository.fetchProfile()
        let profile = try #require(stored)
        #expect(profile.riskTolerance == .aggressive)
        #expect(profile.horizonPreference == .long)
        #expect(profile.concentrationSensitivity == .low)
        #expect(profile.cautionBias == .aggressive)
        #expect(profile.preferDipBuying == true)
    }

    // MARK: - Preferences editing

    @Test("EditPreferencesView commit updates stored preferences")
    func preferencesCommitUpdatesStoredRecord() throws {
        let env = try makeEnv()

        var draft = DraftPreferences(editing: env.preferencesRepository.currentPreferences!)
        draft.morningBriefHour = 9
        draft.morningBriefMinute = 30
        draft.quoteRefreshCadenceMinutes = 30
        draft.priceAlertsEnabled = false
        draft.watchlistAlertsEnabled = false
        draft.holdingRiskAlertsEnabled = true
        draft.recommendationChangeAlertsEnabled = true
        draft.contextualHelpEnabled = false

        try env.preferencesRepository.commit(draft: draft)

        let stored = try #require(env.preferencesRepository.currentPreferences)
        #expect(stored.morningBriefHour == 9)
        #expect(stored.morningBriefMinute == 30)
        #expect(stored.quoteRefreshCadenceMinutes == 30)
        #expect(stored.priceAlertsEnabled == false)
        #expect(stored.watchlistAlertsEnabled == false)
        #expect(stored.holdingRiskAlertsEnabled == true)
        #expect(stored.recommendationChangeAlertsEnabled == true)
        #expect(stored.contextualHelpEnabled == false)
    }

    // MARK: - Reset

    @Test("Reset wipes accounts, holdings, watchlist items, history, and cache")
    func resetWipesData() throws {
        let env = try makeEnv()
        let context = env.modelContainer.mainContext

        // Populate some data across every wiped entity type.
        let account = try env.portfolioRepository.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "To Be Wiped"
        ))
        _ = try env.portfolioRepository.commit(draftHolding: DraftHolding(
            accountID: account.id, symbol: "AAPL", assetType: .stock,
            shares: 1, averageCost: 100
        ))
        _ = try env.watchlistRepository.commit(draftItem: DraftWatchlistItem(
            watchlistKind: .standard, symbol: "SPY", assetType: .etf
        ))
        env.historyService.snapshotAccount(account)
        _ = env.historyService.recordContribution(to: account, amount: 500)
        context.insert(CachedQuote(
            symbol: "AAPL", price: 100, change: 0, changePercent: 0,
            currency: "USD", providerName: "Primary", fetchedAt: Date()
        ))
        try context.save()

        // Sanity pre-wipe
        #expect(try context.fetch(FetchDescriptor<Account>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<Holding>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<WatchlistItem>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<AccountSnapshot>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<ContributionEvent>()).count == 1)
        #expect(try context.fetch(FetchDescriptor<CachedQuote>()).count == 1)

        env.resetAllData()

        #expect(try context.fetch(FetchDescriptor<Account>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<Holding>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<WatchlistItem>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<HoldingSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<AccountSnapshot>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<ContributionEvent>()).isEmpty)
        #expect(try context.fetch(FetchDescriptor<CachedQuote>()).isEmpty)
    }

    @Test("Reset sets firstLaunchComplete to false")
    func resetFlipsFirstLaunchComplete() throws {
        let env = try makeEnv()
        try env.preferencesRepository.markFirstLaunchComplete()
        #expect(env.preferencesRepository.currentPreferences?.firstLaunchComplete == true)

        env.resetAllData()

        #expect(env.preferencesRepository.currentPreferences?.firstLaunchComplete == false)
    }

    @Test("Reset does not delete the InvestingProfile record")
    func resetPreservesInvestingProfile() throws {
        let env = try makeEnv()
        _ = try env.profileRepository.commit(draft: DraftProfile(
            riskTolerance: .aggressive,
            horizonPreference: .long,
            concentrationSensitivity: .low,
            preferDipBuying: true,
            cautionBias: .aggressive
        ))
        #expect(try env.profileRepository.fetchProfile() != nil)

        env.resetAllData()

        let still = try env.profileRepository.fetchProfile()
        #expect(still != nil)
        #expect(still?.riskTolerance == .aggressive)
    }

    @Test("Watchlist seed re-runs cleanly after a reset (seedDefaultsIfNeeded idempotency)")
    func watchlistSeedAfterReset() throws {
        let env = try makeEnv()
        let context = env.modelContainer.mainContext

        #expect(try context.fetch(FetchDescriptor<Watchlist>()).count == WatchlistKind.allCases.count)

        env.resetAllData()

        // resetAllData re-seeds internally; a second explicit seed must stay idempotent.
        try env.watchlistRepository.seedDefaultsIfNeeded()

        let lists = try context.fetch(FetchDescriptor<Watchlist>())
        #expect(lists.count == WatchlistKind.allCases.count)
        #expect(Set(lists.map(\.kind)) == Set(WatchlistKind.allCases))
    }
}
