import Foundation
import SwiftData

/// Per-account override for selected `InvestingProfile` fields. When
/// present, `EffectiveProfile.resolve` uses any non-nil override value in
/// place of the global profile field.
///
/// `accountID` stores the app-level `Account.id` (UUID). This matches the
/// convention used by `Recommendation` and `HoldingSnapshot` — we
/// deliberately do not use `PersistentIdentifier` here because SwiftData
/// `#Predicate` support for persistent-identifier-typed attributes is
/// spotty, while UUID predicates are well-exercised throughout the
/// codebase.
///
/// Each field is Optional: `nil` means "use the global profile value".
/// If all three are `nil` the entire override should be deleted rather
/// than persisted as a no-op (handled in `ProfileRepository.setOverride`).
///
/// The override hangs off `InvestingProfile.accountOverrides` via a
/// cascade-delete relationship, so wiping the profile wipes overrides.
@Model
final class AccountOverride {
    @Attribute(.unique) var id: UUID
    var accountID: UUID
    var riskTolerance: RiskTolerance?
    var horizonPreference: HorizonPreference?
    var cautionBias: CautionBias?

    init(
        id: UUID = UUID(),
        accountID: UUID,
        riskTolerance: RiskTolerance? = nil,
        horizonPreference: HorizonPreference? = nil,
        cautionBias: CautionBias? = nil
    ) {
        self.id = id
        self.accountID = accountID
        self.riskTolerance = riskTolerance
        self.horizonPreference = horizonPreference
        self.cautionBias = cautionBias
    }

    /// True when every override field is nil — nothing would change about
    /// the effective profile. Callers use this to avoid persisting no-op
    /// rows.
    var isNoOp: Bool {
        riskTolerance == nil && horizonPreference == nil && cautionBias == nil
    }
}
