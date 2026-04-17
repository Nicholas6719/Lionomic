import Foundation
import SwiftData
import os

@Observable
final class AppEnvironment {
    let modelContainer: ModelContainer
    let profileRepository: ProfileRepository
    let portfolioRepository: PortfolioRepository
    let watchlistRepository: WatchlistRepository

    init(modelContainer: ModelContainer) {
        self.modelContainer = modelContainer
        let context = modelContainer.mainContext
        self.profileRepository = ProfileRepository(modelContext: context)
        self.portfolioRepository = PortfolioRepository(modelContext: context)
        self.watchlistRepository = WatchlistRepository(modelContext: context)
    }

    func seedOnFirstLaunch() {
        do {
            try watchlistRepository.seedDefaultsIfNeeded()
        } catch {
            Log.persistence.error("Failed to seed default watchlists: \(String(describing: error), privacy: .public)")
        }
    }
}
