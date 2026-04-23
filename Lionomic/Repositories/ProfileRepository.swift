import Foundation
import SwiftData

struct DraftProfile: Hashable {
    var riskTolerance: RiskTolerance
    var horizonPreference: HorizonPreference
    var concentrationSensitivity: ConcentrationSensitivity
    var preferDipBuying: Bool
    var cautionBias: CautionBias

    init(from profile: InvestingProfile) {
        self.riskTolerance = profile.riskTolerance
        self.horizonPreference = profile.horizonPreference
        self.concentrationSensitivity = profile.concentrationSensitivity
        self.preferDipBuying = profile.preferDipBuying
        self.cautionBias = profile.cautionBias
    }

    init(
        riskTolerance: RiskTolerance = .moderate,
        horizonPreference: HorizonPreference = .balanced,
        concentrationSensitivity: ConcentrationSensitivity = .medium,
        preferDipBuying: Bool = false,
        cautionBias: CautionBias = .balanced
    ) {
        self.riskTolerance = riskTolerance
        self.horizonPreference = horizonPreference
        self.concentrationSensitivity = concentrationSensitivity
        self.preferDipBuying = preferDipBuying
        self.cautionBias = cautionBias
    }
}

@MainActor
final class ProfileRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func fetchProfile() throws -> InvestingProfile? {
        try modelContext.fetch(FetchDescriptor<InvestingProfile>()).first
    }

    @discardableResult
    func commit(draft: DraftProfile) throws -> InvestingProfile {
        if let existing = try fetchProfile() {
            existing.riskTolerance = draft.riskTolerance
            existing.horizonPreference = draft.horizonPreference
            existing.concentrationSensitivity = draft.concentrationSensitivity
            existing.preferDipBuying = draft.preferDipBuying
            existing.cautionBias = draft.cautionBias
            existing.updatedAt = Date()
            try modelContext.save()
            return existing
        }
        let new = InvestingProfile(
            riskTolerance: draft.riskTolerance,
            horizonPreference: draft.horizonPreference,
            concentrationSensitivity: draft.concentrationSensitivity,
            preferDipBuying: draft.preferDipBuying,
            cautionBias: draft.cautionBias
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    // MARK: - Per-account overrides (MProfile)

    /// Returns the existing `AccountOverride` for `account`, or nil.
    /// Reads through the global InvestingProfile's `accountOverrides`
    /// relationship so the query stays inside SwiftData's object graph
    /// rather than issuing a separate predicate fetch.
    func override(for account: Account) -> AccountOverride? {
        let profile = (try? fetchProfile()) ?? nil
        let accountID = account.id
        return profile?.accountOverrides.first { $0.accountID == accountID }
    }

    /// Upserts a per-account override. If all three override fields are
    /// nil, the existing override (if any) is deleted rather than
    /// persisted — a no-op override would be wasteful storage and would
    /// show up as "has override" in the UI indicator without changing
    /// any effective profile field.
    ///
    /// Requires the global `InvestingProfile` to exist. If there's no
    /// profile yet the call is a silent no-op (onboarding creates the
    /// profile before the user could reach this surface).
    func setOverride(
        for account: Account,
        riskTolerance: RiskTolerance?,
        horizonPreference: HorizonPreference?,
        cautionBias: CautionBias?
    ) throws {
        // Collapse no-op overrides into a delete.
        if riskTolerance == nil && horizonPreference == nil && cautionBias == nil {
            try clearOverride(for: account)
            return
        }

        guard let profile = try fetchProfile() else { return }
        let accountID = account.id

        if let existing = profile.accountOverrides.first(where: { $0.accountID == accountID }) {
            existing.riskTolerance = riskTolerance
            existing.horizonPreference = horizonPreference
            existing.cautionBias = cautionBias
        } else {
            let new = AccountOverride(
                accountID: accountID,
                riskTolerance: riskTolerance,
                horizonPreference: horizonPreference,
                cautionBias: cautionBias
            )
            // Inserting into the relationship collection is how SwiftData
            // wires the inverse link + the cascade-delete chain.
            profile.accountOverrides.append(new)
            modelContext.insert(new)
        }
        try modelContext.save()
    }

    /// Removes the `AccountOverride` for `account`, if one exists.
    /// Thin wrapper around the UUID-keyed overload so callers holding an
    /// `Account` reference don't have to reach into `account.id` themselves.
    func clearOverride(for account: Account) throws {
        try clearOverride(for: account.id)
    }

    /// MBackground: UUID-keyed overload used by
    /// `PortfolioRepository.commitDelete(_:)` to purge any orphaned
    /// override when its owning Account is deleted. Idempotent — missing
    /// overrides are a no-op, not an error, since deletion is the only
    /// path that calls this and the account may never have had one.
    func clearOverride(for accountID: UUID) throws {
        guard let profile = try fetchProfile() else { return }
        guard let existing = profile.accountOverrides.first(where: { $0.accountID == accountID }) else {
            return
        }
        modelContext.delete(existing)
        try modelContext.save()
    }
}
