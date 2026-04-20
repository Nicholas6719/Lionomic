import Foundation
import SwiftData

/// Thin SwiftData wrapper for `AlertEvent`. No draft layer — alerts are
/// fired programmatically by services, never authored in a review sheet,
/// so `add(_:)` takes a fully-constructed event.
@MainActor
final class AlertRepository {

    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    /// Insert a pre-constructed event. Saves immediately so background
    /// callers (BGTask handlers, recommendation service) don't lose events
    /// on a subsequent crash.
    func add(_ event: AlertEvent) throws {
        modelContext.insert(event)
        try modelContext.save()
    }

    /// All events, newest first.
    func fetchAll() throws -> [AlertEvent] {
        let descriptor = FetchDescriptor<AlertEvent>(
            sortBy: [SortDescriptor(\.firedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Unread subset of `fetchAll()`. Predicate on a Bool is safe with
    /// `#Predicate` — the enum-only restriction doesn't apply here.
    func fetchUnread() throws -> [AlertEvent] {
        let descriptor = FetchDescriptor<AlertEvent>(
            predicate: #Predicate<AlertEvent> { $0.isRead == false },
            sortBy: [SortDescriptor(\.firedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    /// Mark a single event as read. Cheap and idempotent.
    func markRead(_ event: AlertEvent) throws {
        event.isRead = true
        try modelContext.save()
    }

    /// Wipe every event. Called from `AppEnvironment.resetAllData()`.
    func deleteAll() throws {
        let all = try modelContext.fetch(FetchDescriptor<AlertEvent>())
        for event in all {
            modelContext.delete(event)
        }
        try modelContext.save()
    }
}
