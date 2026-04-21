import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Exercises `ProfileRepository.setOverride` / `override(for:)` /
/// `clearOverride(for:)`. Every test builds a fresh in-memory container
/// with a global `InvestingProfile` already committed so the override
/// relationship has a parent row to hang off.
@MainActor
struct AccountOverrideRepositoryTests {

    private struct Bundle {
        let profileRepo: ProfileRepository
        let portfolio: PortfolioRepository
        let context: ModelContext
    }

    private func makeBundle() throws -> Bundle {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        let profileRepo = ProfileRepository(modelContext: context)
        _ = try profileRepo.commit(draft: DraftProfile())
        let portfolio = PortfolioRepository(modelContext: context)
        return Bundle(profileRepo: profileRepo, portfolio: portfolio, context: context)
    }

    @Test func setOverridePersistsAllThreeFields() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .rothIRA, displayName: "Retirement"
        ))

        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: .aggressive,
            horizonPreference: .long,
            cautionBias: .cautious
        )

        let stored = try #require(b.profileRepo.override(for: account))
        #expect(stored.riskTolerance == .aggressive)
        #expect(stored.horizonPreference == .long)
        #expect(stored.cautionBias == .cautious)
        #expect(stored.accountID == account.id)
    }

    @Test func setOverrideWithAllNilDeletesExistingOverride() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))

        // First set a real override.
        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: .conservative,
            horizonPreference: nil,
            cautionBias: nil
        )
        #expect(b.profileRepo.override(for: account) != nil)

        // Then upsert nil × 3 → deletes.
        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: nil,
            horizonPreference: nil,
            cautionBias: nil
        )
        #expect(b.profileRepo.override(for: account) == nil)
    }

    @Test func clearOverrideRemovesIt() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))

        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: .aggressive,
            horizonPreference: nil,
            cautionBias: nil
        )
        #expect(b.profileRepo.override(for: account) != nil)

        try b.profileRepo.clearOverride(for: account)
        #expect(b.profileRepo.override(for: account) == nil)

        // Idempotent — second clear is a no-op, not an error.
        try b.profileRepo.clearOverride(for: account)
        #expect(b.profileRepo.override(for: account) == nil)
    }

    @Test func setOverrideUpserts() async throws {
        let b = try makeBundle()
        let account = try b.portfolio.commit(draftAccount: DraftAccount(
            kind: .brokerage, displayName: "Main"
        ))

        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: .conservative,
            horizonPreference: nil,
            cautionBias: nil
        )
        try b.profileRepo.setOverride(
            for: account,
            riskTolerance: .aggressive,
            horizonPreference: .long,
            cautionBias: nil
        )

        // Same account should still have exactly one override row stored
        // on the profile's relationship collection.
        let profile = try #require(try b.profileRepo.fetchProfile())
        let forAccount = profile.accountOverrides.filter { $0.accountID == account.id }
        #expect(forAccount.count == 1)
        #expect(forAccount.first?.riskTolerance == .aggressive)
        #expect(forAccount.first?.horizonPreference == .long)
        #expect(forAccount.first?.cautionBias == nil)
    }
}
