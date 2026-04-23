import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// MBackground: when an Account is deleted via `PortfolioRepository`,
/// any `AccountOverride` carrying a matching `accountID` must also be
/// purged. Prior to this milestone the override outlived its account,
/// accumulating stale rows flagged as "has override" by the UI indicator.
@MainActor
struct OrphanedOverrideCleanupTests {

    private struct Bundle {
        let profile: ProfileRepository
        let portfolio: PortfolioRepository
        let context: ModelContext
    }

    private func makeBundle() throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profile = ProfileRepository(modelContext: context)
        _ = try profile.commit(draft: DraftProfile())
        let portfolio = PortfolioRepository(
            modelContext: context,
            profileRepository: profile
        )
        return Bundle(profile: profile, portfolio: portfolio, context: context)
    }

    @Test("Deleting an Account purges its AccountOverride row")
    func deletingAccountRemovesItsOverride() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .rothIRA, displayName: "Retirement"
        ))

        // Set a non-trivial override so there's something to purge.
        try b.profile.setOverride(
            for: account,
            riskTolerance: .aggressive,
            horizonPreference: .long,
            cautionBias: nil
        )
        #expect(b.profile.override(for: account) != nil)

        let accountID = account.id
        try b.portfolio.commitDelete(account)

        // Account is gone from SwiftData.
        let remainingAccounts = (try b.context.fetch(
            FetchDescriptor<Account>(predicate: #Predicate { $0.id == accountID })
        ))
        #expect(remainingAccounts.isEmpty)

        // Override row for that account is gone from the profile's relationship.
        let profile = try #require(try b.profile.fetchProfile())
        #expect(profile.accountOverrides.contains(where: { $0.accountID == accountID }) == false)
    }

    @Test("Deleting an Account without an override is a no-op and does not throw")
    func deletingAccountWithoutOverrideIsHarmless() throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))
        // No override set.

        // Should not throw; should silently do nothing on the override side.
        try b.portfolio.commitDelete(account)

        let profile = try #require(try b.profile.fetchProfile())
        #expect(profile.accountOverrides.isEmpty)
    }

    @Test("Overrides on other accounts are untouched when one account is deleted")
    func siblingOverridesArePreserved() throws {
        let b = try makeBundle()
        let keep = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .rothIRA, displayName: "Keep Me"
        ))
        let bye = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Bye Me"
        ))

        try b.profile.setOverride(for: keep, riskTolerance: .conservative, horizonPreference: nil, cautionBias: nil)
        try b.profile.setOverride(for: bye, riskTolerance: .aggressive, horizonPreference: nil, cautionBias: nil)

        try b.portfolio.commitDelete(bye)

        let profile = try #require(try b.profile.fetchProfile())
        #expect(profile.accountOverrides.count == 1)
        #expect(profile.accountOverrides.first?.accountID == keep.id)
        #expect(profile.accountOverrides.first?.riskTolerance == .conservative)
    }
}
