import Foundation
import SwiftData

@Model
final class Account {
    @Attribute(.unique) var id: UUID
    var kind: AccountKind
    var displayName: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \Holding.account)
    var holdings: [Holding] = []

    init(
        id: UUID = UUID(),
        kind: AccountKind,
        displayName: String,
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.notes = notes
        self.createdAt = createdAt
    }
}
