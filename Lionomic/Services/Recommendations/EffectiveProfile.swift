import Foundation

/// The profile actually seen by recommendation rules. Merges the global
/// `InvestingProfile` with an optional per-account `AccountOverride`.
/// `concentrationSensitivity` and `preferDipBuying` are **not**
/// overridable in V1 and always come from the global profile.
struct EffectiveProfile: Hashable, Sendable {
    let riskTolerance: RiskTolerance
    let horizonPreference: HorizonPreference
    let cautionBias: CautionBias
    let concentrationSensitivity: ConcentrationSensitivity
    let preferDipBuying: Bool
}

extension EffectiveProfile {
    /// Fold the global profile with any per-account override. A nil
    /// override field falls through to the global value. Pure value-type
    /// resolution — safe to call from any actor.
    static func resolve(profile: InvestingProfile, override: AccountOverride?) -> EffectiveProfile {
        EffectiveProfile(
            riskTolerance:            override?.riskTolerance     ?? profile.riskTolerance,
            horizonPreference:        override?.horizonPreference  ?? profile.horizonPreference,
            cautionBias:              override?.cautionBias        ?? profile.cautionBias,
            concentrationSensitivity: profile.concentrationSensitivity,
            preferDipBuying:          profile.preferDipBuying
        )
    }

    /// Convenience for tests and direct call sites: resolve an
    /// EffectiveProfile from a global InvestingProfile with no override.
    static func global(_ profile: InvestingProfile) -> EffectiveProfile {
        resolve(profile: profile, override: nil)
    }
}
