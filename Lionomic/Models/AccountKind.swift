import Foundation

enum AccountKind: String, Codable, CaseIterable, Hashable, Sendable {
    case rothIRA = "roth_ira"
    case brokerage

    var displayName: String {
        switch self {
        case .rothIRA:   return "Roth IRA"
        case .brokerage: return "Brokerage"
        }
    }
}
