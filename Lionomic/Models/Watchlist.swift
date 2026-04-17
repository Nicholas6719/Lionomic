import Foundation
import SwiftData

@Model
final class Watchlist {
    var kind: WatchlistKind
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \WatchlistItem.watchlist)
    var items: [WatchlistItem] = []

    init(kind: WatchlistKind, createdAt: Date = Date()) {
        self.kind = kind
        self.createdAt = createdAt
    }
}
