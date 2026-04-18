import Foundation

enum WatchlistKind: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case highPriorityOpportunity = "high_priority_opportunity"

    var displayName: String {
        switch self {
        case .standard:                 return "Standard"
        case .highPriorityOpportunity:  return "High-Priority Opportunity"
        }
    }
}
