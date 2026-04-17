import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct ProfileRepositoryTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        return ModelContext(container)
    }

    @Test func fetchReturnsNilWhenEmpty() async throws {
        let repo = ProfileRepository(modelContext: try makeContext())
        #expect(try repo.fetchProfile() == nil)
    }

    @Test func commitCreatesProfileWhenNoneExists() async throws {
        let context = try makeContext()
        let repo = ProfileRepository(modelContext: context)
        let draft = DraftProfile(
            riskTolerance: .aggressive,
            horizonPreference: .long,
            concentrationSensitivity: .low,
            preferDipBuying: true,
            cautionBias: .balanced
        )

        let saved = try repo.commit(draft: draft)

        #expect(saved.riskTolerance == .aggressive)
        #expect(saved.horizonPreference == .long)
        #expect(saved.preferDipBuying == true)
        #expect(try repo.fetchProfile()?.riskTolerance == .aggressive)
    }

    @Test func commitUpdatesExistingProfileInPlaceAndKeepsSingleRow() async throws {
        let context = try makeContext()
        let repo = ProfileRepository(modelContext: context)

        _ = try repo.commit(draft: DraftProfile())
        _ = try repo.commit(draft: DraftProfile(
            riskTolerance: .conservative,
            horizonPreference: .short,
            concentrationSensitivity: .high,
            preferDipBuying: false,
            cautionBias: .cautious
        ))

        let all = try context.fetch(FetchDescriptor<InvestingProfile>())
        #expect(all.count == 1)
        #expect(all.first?.riskTolerance == .conservative)
        #expect(all.first?.cautionBias == .cautious)
    }
}
