import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct AlertRepositoryTests {

    private func makeRepo() throws -> AlertRepository {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return AlertRepository(modelContext: context)
    }

    @Test func addAndFetchAllReturnsEventInDescendingOrder() async throws {
        let repo = try makeRepo()
        let older = AlertEvent(
            kind: .holdingRisk, symbol: "AAPL",
            title: "t1", body: "b1",
            firedAt: Date(timeIntervalSinceNow: -3600)
        )
        let newer = AlertEvent(
            kind: .recommendationChange, symbol: "NVDA",
            title: "t2", body: "b2",
            firedAt: Date()
        )
        try repo.add(older)
        try repo.add(newer)

        let all = try repo.fetchAll()
        #expect(all.count == 2)
        #expect(all.first?.symbol == "NVDA")
        #expect(all.last?.symbol == "AAPL")
    }

    @Test func fetchUnreadFiltersReadEvents() async throws {
        let repo = try makeRepo()
        let read = AlertEvent(kind: .priceAlert, symbol: "X", title: "a", body: "b")
        let unread = AlertEvent(kind: .priceAlert, symbol: "Y", title: "c", body: "d")
        try repo.add(read)
        try repo.add(unread)

        try repo.markRead(read)

        let unreadSet = try repo.fetchUnread()
        #expect(unreadSet.count == 1)
        #expect(unreadSet.first?.symbol == "Y")
    }

    @Test func deleteAllEmptiesRepository() async throws {
        let repo = try makeRepo()
        try repo.add(AlertEvent(kind: .priceAlert, symbol: "A", title: "t", body: "b"))
        try repo.add(AlertEvent(kind: .priceAlert, symbol: "B", title: "t", body: "b"))
        try repo.deleteAll()
        #expect(try repo.fetchAll().isEmpty)
    }

    @Test func kindEnumRoundTrips() async throws {
        let repo = try makeRepo()
        let event = AlertEvent(
            kind: .recommendationChange,
            symbol: "TSLA",
            title: "t", body: "b"
        )
        try repo.add(event)
        let fetched = try repo.fetchAll().first
        #expect(fetched?.kindEnum == .recommendationChange)
        #expect(fetched?.kind == "recommendation_change")
    }
}
