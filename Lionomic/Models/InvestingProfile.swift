import Foundation
import SwiftData

enum RiskTolerance: String, Codable, CaseIterable, Hashable, Sendable {
    case conservative
    case moderate
    case aggressive

    var displayName: String {
        switch self {
        case .conservative: return "Conservative"
        case .moderate:     return "Moderate"
        case .aggressive:   return "Aggressive"
        }
    }
}

enum HorizonPreference: String, Codable, CaseIterable, Hashable, Sendable {
    case short
    case balanced
    case long

    var displayName: String {
        switch self {
        case .short:    return "Short Term"
        case .balanced: return "Balanced"
        case .long:     return "Long Term"
        }
    }
}

enum ConcentrationSensitivity: String, Codable, CaseIterable, Hashable, Sendable {
    case low
    case medium
    case high

    var displayName: String {
        switch self {
        case .low:    return "Low"
        case .medium: return "Medium"
        case .high:   return "High"
        }
    }
}

enum CautionBias: String, Codable, CaseIterable, Hashable, Sendable {
    case cautious
    case balanced
    case aggressive

    var displayName: String {
        switch self {
        case .cautious:   return "Cautious"
        case .balanced:   return "Balanced"
        case .aggressive: return "Aggressive"
        }
    }
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
