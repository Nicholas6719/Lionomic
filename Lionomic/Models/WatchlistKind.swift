import Foundation

enum WatchlistKind: String, Codable, CaseIterable, Hashable, Sendable {
    case standard
    case highPriorityOpportunity = "high_priority_opportunity"
}
