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
}
