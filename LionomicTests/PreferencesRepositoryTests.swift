import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct PreferencesRepositoryTests {

    /// Build a fresh in-memory container + ModelContext. Matches the pattern used by the
    /// Profile/Portfolio/Watchlist test suites — `container.mainContext` has been observed
    /// to crash Swift Testing's parallel runner on iOS 26.4; a freshly-allocated context
    /// is isolated per test process and avoids the issue.
    private func makeRepository() throws -> (PreferencesRepository, ModelContext) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (PreferencesRepository(context: context), context)
    }

    @Test("load() creates a default preferences record on first run")
    func loadCreatesDefaultsOnFirstRun() throws {
        let (repo, _) = try makeRepository()
        try repo.load()

        let prefs = try #require(repo.currentPreferences)
        #expect(prefs.biometricsEnabled == true)
        #expect(prefs.firstLaunchComplete == false)
        #expect(prefs.morningBriefHour == 7)
        #expect(prefs.morningBriefMinute == 15)
        #expect(prefs.quoteRefreshCadenceMinutes == 5)
    }

    @Test("load() is idempotent — calling twice does not create a second record")
    func loadIsIdempotent() throws {
        let (repo, context) = try makeRepository()

        try repo.load()
        let firstID = repo.currentPreferences?.persistentModelID

        try repo.load()
        let secondID = repo.currentPreferences?.persistentModelID

        #expect(firstID == secondID)

        let allRecords = try context.fetch(FetchDescriptor<AppPreferences>())
        #expect(allRecords.count == 1)
    }

    @Test("commit() applies all draft values to the stored record")
    func commitAppliesDraftValues() throws {
        let (repo, _) = try makeRepository()
        try repo.load()

        var draft = DraftPreferences()
        draft.biometricsEnabled = false
        draft.morningBriefHour = 7
        draft.morningBriefMinute = 30
        draft.quoteRefreshCadenceMinutes = 30
        draft.priceAlertsEnabled = false
        draft.watchlistAlertsEnabled = false
        draft.holdingRiskAlertsEnabled = false
        draft.recommendationChangeAlertsEnabled = false

        try repo.commit(draft: draft)

        let prefs = try #require(repo.currentPreferences)
        #expect(prefs.biometricsEnabled == false)
        #expect(prefs.morningBriefHour == 7)
        #expect(prefs.morningBriefMinute == 30)
        #expect(prefs.quoteRefreshCadenceMinutes == 30)
        #expect(prefs.priceAlertsEnabled == false)
        #expect(prefs.watchlistAlertsEnabled == false)
        #expect(prefs.holdingRiskAlertsEnabled == false)
        #expect(prefs.recommendationChangeAlertsEnabled == false)
    }

    @Test("commit() without a prior load() still creates a record defensively")
    func commitWithoutLoadCreatesRecord() throws {
        let (repo, _) = try makeRepository()
        let draft = DraftPreferences()
        try repo.commit(draft: draft)
        #expect(repo.currentPreferences != nil)
    }

    @Test("commit() updates the updatedAt timestamp")
    func commitUpdatesTimestamp() throws {
        let (repo, _) = try makeRepository()
        try repo.load()

        let before = Date()
        try repo.commit(draft: DraftPreferences())
        let after = Date()

        let updatedAt = try #require(repo.currentPreferences?.updatedAt)
        #expect(updatedAt >= before)
        #expect(updatedAt <= after)
    }
}
