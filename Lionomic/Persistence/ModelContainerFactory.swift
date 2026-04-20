import Foundation
import SwiftData

enum ModelContainerFactory {
    static let v1Models: [any PersistentModel.Type] = [
        InvestingProfile.self,
        AppPreferences.self,
        Account.self,
        Holding.self,
        Watchlist.self,
        WatchlistItem.self,
        ContributionEvent.self,
        HoldingSnapshot.self,
        AccountSnapshot.self,
        CachedQuote.self,
        Recommendation.self,
        AlertEvent.self,
    ]

    static func makeSharedContainer(
        models: [any PersistentModel.Type] = v1Models,
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
