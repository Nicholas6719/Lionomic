import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct HistoryServiceTests {

    private func makeService() throws -> (HistoryService, ModelContext) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context   = ModelContext(container)
        return (HistoryService(context: context), context)
    }

    private func makeAccount(in context: ModelContext) -> Account {
        let account = Account(kind: .brokerage, displayName: "Test Brokerage")
        context.insert(account)
        try? context.save()
        return account
    }

    @Test("snapshotHolding inserts a HoldingSnapshot with matching fields")
    func snapshotHoldingInsertsRecord() throws {
        let (service, context) = try makeService()
        let account = makeAccount(in: context)

        let holding = Holding(account: account, symbol: "AAPL", assetType: .stock)
        holding.shares      = 10
        holding.averageCost = 150
        context.insert(holding)
        try context.save()

        service.snapshotHolding(holding)

        let snapshots = try context.fetch(FetchDescriptor<HoldingSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots[0].symbol == "AAPL")
        #expect(snapshots[0].holdingID == holding.id)
        #expect(snapshots[0].shares == 10)
    }

    @Test("snapshotAccount calculates cost-basis total correctly")
    func snapshotAccountCalculatesTotal() throws {
        let (service, context) = try makeService()
        let account = makeAccount(in: context)

        let h1 = Holding(account: account, symbol: "AAPL", assetType: .stock)
        h1.shares = 10; h1.averageCost = 150
        let h2 = Holding(account: account, symbol: "MSFT", assetType: .stock)
        h2.shares = 5; h2.averageCost = 200
        context.insert(h1); context.insert(h2)
        try context.save()

        service.snapshotAccount(account)

        let snapshots = try context.fetch(FetchDescriptor<AccountSnapshot>())
        #expect(snapshots.count == 1)
        #expect(snapshots[0].totalValue == 2500) // (10×150) + (5×200)
    }

    @Test("recordContribution inserts a ContributionEvent")
    func recordContributionInsertsEvent() throws {
        let (service, context) = try makeService()
        let account = makeAccount(in: context)

        let event = service.recordContribution(to: account, amount: 500, note: "Initial deposit")

        #expect(event != nil)
        let events = try context.fetch(FetchDescriptor<ContributionEvent>())
        #expect(events.count == 1)
        #expect(events[0].amount == 500)
    }

    @Test("recordContribution rejects zero amount")
    func recordContributionRejectsZero() throws {
        let (service, context) = try makeService()
        let account = makeAccount(in: context)

        let event = service.recordContribution(to: account, amount: 0)

        #expect(event == nil)
        let events = try context.fetch(FetchDescriptor<ContributionEvent>())
        #expect(events.isEmpty)
    }
}
