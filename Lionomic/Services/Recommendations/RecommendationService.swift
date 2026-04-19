import Foundation
import SwiftData
import os

/// Coordinates the recommendation engine with persistence and market data.
///
/// `generate(for:)` runs the engine over every holding in an account,
/// fetching a quote for each non-NFT symbol (cache-first, then network),
/// and persists the results. Existing recommendations for that account
/// are cleared before the new ones are inserted so the stored set always
/// reflects the latest run.
@MainActor
final class RecommendationService {

    private let modelContext: ModelContext
    private let marketDataService: MarketDataService
    private let profileRepository: ProfileRepository
    private let engine: RecommendationEngine

    init(
        modelContext: ModelContext,
        marketDataService: MarketDataService,
        profileRepository: ProfileRepository,
        engine: RecommendationEngine = RecommendationEngine()
    ) {
        self.modelContext      = modelContext
        self.marketDataService = marketDataService
        self.profileRepository = profileRepository
        self.engine            = engine
    }

    /// Regenerate recommendations for every account and return the full
    /// persisted set (sorted by confidence, descending).
    @discardableResult
    func generateAll(accounts: [Account]) async -> [Recommendation] {
        var all: [Recommendation] = []
        for account in accounts {
            let forAccount = await generate(for: account)
            all.append(contentsOf: forAccount)
        }
        return all.sorted { $0.confidence > $1.confidence }
    }

    /// Regenerate recommendations for a single account.
    @discardableResult
    func generate(for account: Account) async -> [Recommendation] {
        let profile = (try? profileRepository.fetchProfile()) ?? InvestingProfile()
        clearExisting(accountID: account.id)

        var generated: [Recommendation] = []
        for holding in account.holdings {
            let quote = await fetchQuote(for: holding)
            let rec = engine.evaluate(
                holding: holding,
                account: account,
                profile: profile,
                quote: quote
            )
            modelContext.insert(rec)
            generated.append(rec)
        }

        do {
            try modelContext.save()
        } catch {
            Log.persistence.error("RecommendationService save failed: \(String(describing: error), privacy: .public)")
        }
        return generated
    }

    /// Load all persisted recommendations, newest first within each confidence tier.
    func fetchAll() throws -> [Recommendation] {
        let descriptor = FetchDescriptor<Recommendation>(
            sortBy: [
                SortDescriptor(\.confidence, order: .reverse),
                SortDescriptor(\.generatedAt, order: .reverse),
            ]
        )
        return try modelContext.fetch(descriptor)
    }

    // MARK: - Private

    private func fetchQuote(for holding: Holding) async -> QuoteResult? {
        guard holding.assetType.usesMarketQuote else { return nil }
        if let cached = await marketDataService.cachedQuote(for: holding.symbol), cached.isFresh {
            return cached
        }
        return try? await marketDataService.fetchQuote(symbol: holding.symbol)
    }

    private func clearExisting(accountID: UUID) {
        let descriptor = FetchDescriptor<Recommendation>(
            predicate: #Predicate<Recommendation> { $0.accountID == accountID }
        )
        if let existing = try? modelContext.fetch(descriptor) {
            for rec in existing {
                modelContext.delete(rec)
            }
        }
    }
}
