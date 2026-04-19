import Foundation
import SwiftData
import SwiftUI

enum RecommendationCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case buyNow = "buy_now"
    case wait
    case hold
    case reduce
    case avoid
    case researchMore = "research_more"

    var displayName: String {
        switch self {
        case .buyNow:        return "Buy Now"
        case .wait:          return "Wait"
        case .hold:          return "Hold"
        case .reduce:        return "Reduce"
        case .avoid:         return "Avoid"
        case .researchMore:  return "Research More"
        }
    }

    /// Suggested accent color for UI badging. Kept here so every surface that
    /// renders a category uses the same palette.
    var badgeColor: Color {
        switch self {
        case .buyNow:        return .green
        case .wait:          return .orange
        case .hold:          return .blue
        case .reduce:        return .red
        case .avoid:         return .pink
        case .researchMore:  return .gray
        }
    }
}

/// A persisted recommendation produced by the engine for a single holding.
/// `holdingID` / `accountID` are stored as UUIDs (not relationships) so
/// history survives holding or account deletion — same pattern as
/// `HoldingSnapshot`. `assetType` and `category` are stored as raw Strings
/// for SwiftData compatibility (enum-typed properties cause issues with
/// `@Attribute(.unique)` and `#Predicate`).
@Model
final class Recommendation {

    @Attribute(.unique) var id: UUID
    var holdingID: UUID
    var accountID: UUID
    var symbol: String
    var assetType: String
    var category: String
    var reasoning: String
    var confidence: Double
    var cautionNote: String
    var generatedAt: Date

    init(
        id: UUID = UUID(),
        holdingID: UUID,
        accountID: UUID,
        symbol: String,
        assetType: AssetType,
        category: RecommendationCategory,
        reasoning: String,
        confidence: Double,
        cautionNote: String = "",
        generatedAt: Date = .now
    ) {
        self.id          = id
        self.holdingID   = holdingID
        self.accountID   = accountID
        self.symbol      = symbol
        self.assetType   = assetType.rawValue
        self.category    = category.rawValue
        self.reasoning   = reasoning
        self.confidence  = confidence
        self.cautionNote = cautionNote
        self.generatedAt = generatedAt
    }

    var categoryEnum: RecommendationCategory {
        RecommendationCategory(rawValue: category) ?? .researchMore
    }

    var assetTypeEnum: AssetType {
        AssetType(rawValue: assetType) ?? .stock
    }
}
