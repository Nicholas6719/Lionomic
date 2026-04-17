import Foundation
import SwiftData

struct DraftAccount: Hashable {
    var id: UUID?
    var kind: AccountKind
    var displayName: String
    var notes: String

    init(id: UUID? = nil, kind: AccountKind, displayName: String, notes: String = "") {
        self.id = id
        self.kind = kind
        self.displayName = displayName
        self.notes = notes
    }

    init(editing account: Account) {
        self.id = account.id
        self.kind = account.kind
        self.displayName = account.displayName
        self.notes = account.notes
    }
}

struct DraftHolding: Hashable {
    var id: UUID?
    var accountId: UUID
    var symbol: String
    var assetType: AssetType
    var shares: Decimal?
    var averageCost: Decimal?
    var manualValuation: Decimal?
    var notes: String

    init(
        id: UUID? = nil,
        accountId: UUID,
        symbol: String,
        assetType: AssetType,
        shares: Decimal? = nil,
        averageCost: Decimal? = nil,
        manualValuation: Decimal? = nil,
        notes: String = ""
    ) {
        self.id = id
        self.accountId = accountId
        self.symbol = symbol
        self.assetType = assetType
        self.shares = shares
        self.averageCost = averageCost
        self.manualValuation = manualValuation
        self.notes = notes
    }

    init(editing holding: Holding) {
        self.id = holding.id
        self.accountId = holding.account?.id ?? UUID()
        self.symbol = holding.symbol
        self.assetType = holding.assetType
        self.shares = holding.shares
        self.averageCost = holding.averageCost
        self.manualValuation = holding.manualValuation
        self.notes = holding.notes
    }

    var normalizedSymbol: String {
        Holding.normalize(symbol: symbol)
    }
}

enum PortfolioRepositoryError: Error, Equatable {
    case accountNotFound
    case holdingNotFound
    case duplicateSymbolInAccount(existingHoldingId: UUID)
    case emptySymbol
    case nftRequiresManualValuation
    case nonNFTRequiresSharesAndCost
}

@MainActor
final class PortfolioRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Accounts

    func fetchAccounts() throws -> [Account] {
        let descriptor = FetchDescriptor<Account>(
            sortBy: [SortDescriptor(\.createdAt)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchAccount(id: UUID) throws -> Account? {
        let descriptor = FetchDescriptor<Account>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func commit(draftAccount draft: DraftAccount) throws -> Account {
        if let id = draft.id {
            guard let existing = try fetchAccount(id: id) else {
                throw PortfolioRepositoryError.accountNotFound
            }
            existing.kind = draft.kind
            existing.displayName = draft.displayName
            existing.notes = draft.notes
            try modelContext.save()
            return existing
        }
        let new = Account(
            kind: draft.kind,
            displayName: draft.displayName,
            notes: draft.notes
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    func commitDelete(_ account: Account) throws {
        modelContext.delete(account)
        try modelContext.save()
    }

    // MARK: - Holdings

    func fetchHoldings(in account: Account) throws -> [Holding] {
        let accountId = account.id
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.account?.id == accountId },
            sortBy: [SortDescriptor(\.symbol)]
        )
        return try modelContext.fetch(descriptor)
    }

    func fetchHolding(id: UUID) throws -> Holding? {
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func fetchHolding(in account: Account, symbol: String) throws -> Holding? {
        let accountId = account.id
        let normalized = Holding.normalize(symbol: symbol)
        let descriptor = FetchDescriptor<Holding>(
            predicate: #Predicate { $0.account?.id == accountId && $0.symbol == normalized }
        )
        return try modelContext.fetch(descriptor).first
    }

    @discardableResult
    func commit(draftHolding draft: DraftHolding) throws -> Holding {
        try Self.validate(draft)

        guard let account = try fetchAccount(id: draft.accountId) else {
            throw PortfolioRepositoryError.accountNotFound
        }

        let normalized = draft.normalizedSymbol

        if let id = draft.id {
            guard let existing = try fetchHolding(id: id) else {
                throw PortfolioRepositoryError.holdingNotFound
            }
            if existing.symbol != normalized,
               let conflict = try fetchHolding(in: account, symbol: normalized) {
                throw PortfolioRepositoryError.duplicateSymbolInAccount(
                    existingHoldingId: conflict.id
                )
            }
            apply(draft, to: existing)
            existing.updatedAt = Date()
            try modelContext.save()
            return existing
        }

        if let conflict = try fetchHolding(in: account, symbol: normalized) {
            throw PortfolioRepositoryError.duplicateSymbolInAccount(
                existingHoldingId: conflict.id
            )
        }

        let new = Holding(
            account: account,
            symbol: normalized,
            assetType: draft.assetType,
            shares: draft.shares,
            averageCost: draft.averageCost,
            manualValuation: draft.manualValuation,
            valuationUpdatedAt: draft.assetType == .nft ? Date() : nil,
            notes: draft.notes
        )
        modelContext.insert(new)
        try modelContext.save()
        return new
    }

    func commitDelete(_ holding: Holding) throws {
        modelContext.delete(holding)
        try modelContext.save()
    }

    // MARK: - Private

    private func apply(_ draft: DraftHolding, to holding: Holding) {
        holding.symbol = draft.normalizedSymbol
        holding.assetType = draft.assetType
        holding.shares = draft.shares
        holding.averageCost = draft.averageCost
        holding.manualValuation = draft.manualValuation
        holding.notes = draft.notes
        if draft.assetType == .nft {
            holding.valuationUpdatedAt = Date()
        } else {
            holding.valuationUpdatedAt = nil
        }
    }

    private static func validate(_ draft: DraftHolding) throws {
        guard !draft.normalizedSymbol.isEmpty else {
            throw PortfolioRepositoryError.emptySymbol
        }
        switch draft.assetType {
        case .nft:
            guard draft.manualValuation != nil else {
                throw PortfolioRepositoryError.nftRequiresManualValuation
            }
        case .stock, .etf, .indexFund, .mutualFund:
            guard draft.shares != nil, draft.averageCost != nil else {
                throw PortfolioRepositoryError.nonNFTRequiresSharesAndCost
            }
        }
    }
}
