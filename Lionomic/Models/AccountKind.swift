import Foundation

enum AccountKind: String, Codable, CaseIterable, Hashable, Sendable {
    case rothIRA = "roth_ira"
    case brokerage
}
