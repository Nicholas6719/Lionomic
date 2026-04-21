import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Unit tests for `EffectiveProfile.resolve`. Pure value-type behavior —
/// the override model needs no persistence here; it's built in-memory.
@MainActor
struct EffectiveProfileTests {

    private func makeGlobal() -> InvestingProfile {
        InvestingProfile(
            riskTolerance: .moderate,
            horizonPreference: .balanced,
            concentrationSensitivity: .medium,
            preferDipBuying: false,
            cautionBias: .balanced
        )
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    }

    @Test func resolveUsesOverrideRiskToleranceWhenPresent() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = makeGlobal()
        context.insert(global)
        let override = AccountOverride(
            accountID: UUID(),
            riskTolerance: .aggressive,
            horizonPreference: nil,
            cautionBias: nil
        )
        context.insert(override)

        let effective = EffectiveProfile.resolve(profile: global, override: override)
        #expect(effective.riskTolerance == .aggressive)
        // Other two should still come from global.
        #expect(effective.horizonPreference == .balanced)
        #expect(effective.cautionBias == .balanced)
    }

    @Test func resolveFallsBackToGlobalRiskToleranceWhenOverrideNil() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = makeGlobal()
        context.insert(global)
        let override = AccountOverride(
            accountID: UUID(),
            riskTolerance: nil,            // nil — fallback
            horizonPreference: .long,
            cautionBias: nil
        )
        context.insert(override)

        let effective = EffectiveProfile.resolve(profile: global, override: override)
        #expect(effective.riskTolerance == .moderate)   // from global
        #expect(effective.horizonPreference == .long)   // from override
    }

    @Test func resolveAlwaysUsesGlobalConcentrationSensitivity() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = InvestingProfile(
            riskTolerance: .moderate,
            horizonPreference: .balanced,
            concentrationSensitivity: .low,
            preferDipBuying: false,
            cautionBias: .balanced
        )
        context.insert(global)
        // Override everything else — concentrationSensitivity is not on
        // AccountOverride by design and should stay global.
        let override = AccountOverride(
            accountID: UUID(),
            riskTolerance: .aggressive,
            horizonPreference: .long,
            cautionBias: .aggressive
        )
        context.insert(override)

        let effective = EffectiveProfile.resolve(profile: global, override: override)
        #expect(effective.concentrationSensitivity == .low)
    }

    @Test func resolveAlwaysUsesGlobalPreferDipBuying() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = InvestingProfile(
            riskTolerance: .moderate,
            horizonPreference: .balanced,
            concentrationSensitivity: .medium,
            preferDipBuying: true,   // globally on
            cautionBias: .balanced
        )
        context.insert(global)
        let override = AccountOverride(
            accountID: UUID(),
            riskTolerance: .conservative,
            horizonPreference: .short,
            cautionBias: .cautious
        )
        context.insert(override)

        let effective = EffectiveProfile.resolve(profile: global, override: override)
        #expect(effective.preferDipBuying == true)
    }

    @Test func resolveWithNilOverrideReturnsAllGlobalValues() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = makeGlobal()
        context.insert(global)

        let effective = EffectiveProfile.resolve(profile: global, override: nil)
        #expect(effective.riskTolerance == global.riskTolerance)
        #expect(effective.horizonPreference == global.horizonPreference)
        #expect(effective.cautionBias == global.cautionBias)
        #expect(effective.concentrationSensitivity == global.concentrationSensitivity)
        #expect(effective.preferDipBuying == global.preferDipBuying)
    }

    @Test func resolvePartialOverride() async throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let global = makeGlobal()
        context.insert(global)
        // Only horizonPreference is overridden — the other two stay global.
        let override = AccountOverride(
            accountID: UUID(),
            riskTolerance: nil,
            horizonPreference: .long,
            cautionBias: nil
        )
        context.insert(override)

        let effective = EffectiveProfile.resolve(profile: global, override: override)
        #expect(effective.horizonPreference == .long)
        #expect(effective.riskTolerance == .moderate)
        #expect(effective.cautionBias == .balanced)
    }
}
