import Foundation
import SwiftData

/// The kind of alert an `AlertEvent` represents. Raw-String stored so
/// SwiftData's `@Attribute(.unique)` + `#Predicate` restrictions on
/// enum-typed properties don't apply — same pattern as
/// `Recommendation.category` and `Holding.assetType`.
enum AlertKind: String, Codable, CaseIterable, Hashable, Sendable {
    case recommendationChange = "recommendation_change"
    case holdingRisk          = "holding_risk"
    case priceAlert           = "price_alert"
    case watchlistAlert       = "watchlist_alert"

    var displayName: String {
        switch self {
        case .recommendationChange: return "Recommendation Change"
        case .holdingRisk:          return "Holding Risk"
        case .priceAlert:           return "Price Alert"
        case .watchlistAlert:       return "Watchlist Alert"
        }
    }
}

/// A persisted record of a fired alert. Append-only — we store these so
/// a future alerts list UI (M11 polish) can render history, and so the
/// holding-risk dedupe window can consult prior firings.
///
/// `kind` is stored as a raw `String`. `symbol` is always present
/// (alerts are always about a specific symbol in V1).
@Model
final class AlertEvent {

    @Attribute(.unique) var id: UUID
    var kind: String
    var symbol: String
    var title: String
    var body: String
    var firedAt: Date
    var isRead: Bool

    init(
        id: UUID = UUID(),
        kind: AlertKind,
        symbol: String,
        title: String,
        body: String,
        firedAt: Date = .now,
        isRead: Bool = false
    ) {
        self.id      = id
        self.kind    = kind.rawValue
        self.symbol  = symbol
        self.title   = title
        self.body    = body
        self.firedAt = firedAt
        self.isRead  = isRead
    }

    var kindEnum: AlertKind {
        AlertKind(rawValue: kind) ?? .priceAlert
    }
}
