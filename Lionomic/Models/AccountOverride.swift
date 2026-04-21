import Foundation
import SwiftData

/// Per-account override for selected `InvestingProfile` fields. When
/// present, `EffectiveProfile.resolve` uses any non-nil override value in
/// place of the global profile field.
///
/// `accountID` stores the app-level `Account.id` (UUID), matching the
/// convention used by `Recommendation` and `HoldingSnapshot`.
///
/// Enum-typed fields are stored as Optional raw `String?` values with
/// computed accessors on top — same pattern as `Recommendation.category`
/// / `AlertEvent.kind`. This is the only SwiftData-safe way to store
/// Optional enums: persisting the enum type directly leaves SwiftData's
/// lightweight migration unable to materialize the column on an existing
/// store, which surfaces as a crash inside `ModelContainer(...)`.
///
/// The override hangs off `InvestingProfile.accountOverrides` via a
/// cascade-delete relationship, so wiping the profile wipes overrides.
@Model
final class AccountOverride {
    @Attribute(.unique) var id: UUID
    var accountID: UUID

    // Raw storage. Keep these `internal` so SwiftData sees them and
    // `@testable import` tests can inspect them, but drive writes
    // through the computed properties below so the enum round-trip is
    // never skipped.
    var riskToleranceRaw: String?
    var horizonPreferenceRaw: String?
    var cautionBiasRaw: String?

    init(
        id: UUID = UUID(),
        accountID: UUID,
        riskTolerance: RiskTolerance? = nil,
        horizonPreference: HorizonPreference? = nil,
        cautionBias: CautionBias? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.riskToleranceRaw = riskTolerance?.rawValue
        self.horizonPreferenceRaw = horizonPreference?.rawValue
        self.cautionBiasRaw = cautionBias?.rawValue
    }

    // MARK: - Enum accessors

    var riskTolerance: RiskTolerance? {
        get { riskToleranceRaw.flatMap(RiskTolerance.init(rawValue:)) }
        set { riskToleranceRaw = newValue?.rawValue }
    }

    var horizonPreference: HorizonPreference? {
        get { horizonPreferenceRaw.flatMap(HorizonPreference.init(rawValue:)) }
        set { horizonPreferenceRaw = newValue?.rawValue }
    }

    var cautionBias: CautionBias? {
        get { cautionBiasRaw.flatMap(CautionBias.init(rawValue:)) }
        set { cautionBiasRaw = newValue?.rawValue }
    }

    /// True when every override field is nil — nothing would change about
    /// the effective profile. Callers use this to avoid persisting no-op
    /// rows.
    var isNoOp: Bool {
        riskToleranceRaw == nil && horizonPreferenceRaw == nil && cautionBiasRaw == nil
    }
}
