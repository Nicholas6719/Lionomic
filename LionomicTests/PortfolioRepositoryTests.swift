import Testing
import Foundation
import SwiftData
@testable import Lionomic

@MainActor
struct PortfolioRepositoryTests {
    private func makeRepo() throws -> (PortfolioRepository, ModelContext) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = ModelContext(container)
        return (PortfolioRepository(modelContext: context), context)
    }

    private func makeAccount(_ repo: PortfolioRepository, kind: AccountKind = .brokerage) throws -> Account {
        try repo.commit(draftAccount: DraftAccount(kind: kind, displayName: "Test \(kind.rawValue)"))
    }

    @Test func createAccountAndFetchIt() async throws {
        let (repo, _) = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .rothIRA, displayName: "My Roth"))
        let all = try repo.fetchAccounts()
        #expect(all.count == 1)
        #expect(all.first?.id == account.id)
        #expect(all.first?.kind == .rothIRA)
    }

    @Test func editAccountUpdatesSameRecord() async throws {
        let (repo, _) = try makeRepo()
        let account = try repo.commit(draftAccount: DraftAccount(kind: .brokerage, displayName: "Old"))
        _ = try repo.commit(draftAccount: DraftAccount(id: account.id, kind: .brokerage, displayName: "New", notes: "hi"))
        let all = try repo.fetchAccounts()
        #expect(all.count == 1)
        #expect(all.first?.displayName == "New")
        #expect(all.first?.notes == "hi")
    }

    @Test func commitHoldingCreatesNewHolding() async throws {
        let (repo, _) = try makeRepo()
        let account = try makeAccount(repo)

        let holding = try repo.commit(draftHolding: DraftHolding(
            accountId: account.id,
            symbol: "aapl",
            assetType: .stock,
            shares: 10,
            averageCost: 150
        ))

        #expect(holding.symbol == "AAPL")
        #expect(holding.shares == 10)
        #expect(holding.averageCost == 150)
        #expect(holding.account?.id == account.id)
    }

    @Test func duplicateSymbolInSameAccountIsRejected() async throws {
        let (repo, _) = try makeRepo()
        let account = try makeAccount(repo)

        let first = try repo.commit(draftHolding: DraftHolding(
            accountId: account.id,
            symbol: "VTI",
            assetType: .etf,
            shares: 5,
            averageCost: 200
        ))

        #expect(throws: PortfolioRepositoryError.self) {
            _ = try repo.commit(draftHolding: DraftHolding(
                accountId: account.id,
                symbol: "vti",
                assetType: .etf,
                shares: 1,
                averageCost: 210
            ))
        }

        do {
            _ = try repo.commit(draftHolding: DraftHolding(
                accountId: account.id,
                symbol: "VTI",
                assetType: .etf,
                shares: 1,
                averageCost: 210
            ))
            Issue.record("Expected duplicate-symbol throw")
        } catch PortfolioRepositoryError.duplicateSymbolInAccount(let existingId) {
            #expect(existingId == first.id)
        }
    }

    @Test func sameSymbolAllowedInDifferentAccount() async throws {
        let (repo, _) = try makeRepo()
        let roth = try makeAccount(repo, kind: .rothIRA)
        let brokerage = try makeAccount(repo, kind: .brokerage)

        _ = try repo.commit(draftHolding: DraftHolding(
            accountId: roth.id, symbol: "VOO", assetType: .etf, shares: 1, averageCost: 400
        ))
        _ = try repo.commit(draftHolding: DraftHolding(
            accountId: brokerage.id, symbol: "VOO", assetType: .etf, shares: 2, averageCost: 410
        ))

        #expect(try repo.fetchHoldings(in: roth).count == 1)
        #expect(try repo.fetchHoldings(in: brokerage).count == 1)
    }

    @Test func nftRequiresManualValuation() async throws {
        let (repo, _) = try makeRepo()
        let account = try makeAccount(repo)

        #expect(throws: PortfolioRepositoryError.nftRequiresManualValuation) {
            _ = try repo.commit(draftHolding: DraftHolding(
                accountId: account.id,
                symbol: "PUNK-123",
                assetType: .nft
            ))
        }

        let holding = try repo.commit(draftHolding: DraftHolding(
            accountId: account.id,
            symbol: "PUNK-123",
            assetType: .nft,
            manualValuation: 1500
        ))
        #expect(holding.manualValuation == 1500)
        #expect(holding.valuationUpdatedAt != nil)
    }

    @Test func nonNFTRequiresSharesAndCost() async throws {
        let (repo, _) = try makeRepo()
        let account = try makeAccount(repo)

        #expect(throws: PortfolioRepositoryError.nonNFTRequiresSharesAndCost) {
            _ = try repo.commit(draftHolding: DraftHolding(
                accountId: account.id,
                symbol: "AAPL",
                assetType: .stock
            ))
        }
    }

    @Test func deletingAccountCascadesToHoldings() async throws {
        let (repo, context) = try makeRepo()
        let account = try makeAccount(repo)
        _ = try repo.commit(draftHolding: DraftHolding(
            accountId: account.id,
            symbol: "AAPL",
            assetType: .stock,
            shares: 1,
            averageCost: 100
        ))

        try repo.commitDelete(account)

        let remainingHoldings = try context.fetch(FetchDescriptor<Holding>())
        #expect(remainingHoldings.isEmpty)
    }
}
