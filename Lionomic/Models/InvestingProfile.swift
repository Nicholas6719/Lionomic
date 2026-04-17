import Foundation
import SwiftData

enum RiskTolerance: String, Codable, CaseIterable, Hashable, Sendable {
    case conservative
    case moderate
    case aggressive
}

enum HorizonPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case short
    case balanced
    case long
}

enum ConcentrationSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high
}

enum CautionBias: String, Codable, CaseIterable, Hashable, Sendable {
    case cautious
    case balanced
    case aggressive
}

@Model
final class InvestingProfile {
    var riskTolerance: RiskTolerance
    var horizonPreference: HorizonPreference
    var concentrationSensitivity: ConcentrationSensitivity
    var preferDipBuying: Bool
    var cautionBias: CautionBias
    var updatedAt: Date

    init(
        riskTolerance: RiskTolerance = .moderate,
        horizonPreference: HorizonPreference = .balanced,
        concentrationSensitivity: ConcentrationSensitivity = .medium,
        preferDipBuying: Bool = false,
        cautionBias: CautionBias = .balanced,
        updatedAt: Date = Date()
    ) {
        self.riskTolerance = riskTolerance
        self.horizonPreference = horizonPreference
        self.concentrationSensitivity = concentrationSensitivity
        self.preferDipBuying = preferDipBuying
        self.cautionBias = cautionBias
        self.updatedAt = updatedAt
    }
}
