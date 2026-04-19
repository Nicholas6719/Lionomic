import SwiftUI
import SwiftData

/// The Dashboard tab. A vertically-scrollable stack of cards.
/// Cards for features that land later (M7/M8) render placeholder content —
/// hidden features look worse than labeled placeholders.
struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                PortfolioSummaryCard()
                WatchlistHighlightsCard()
                MorningBriefCard()
                RecommendationsCard()
            }
            .padding(16)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Dashboard")
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    try? env.watchlistRepository.seedDefaultsIfNeeded()
    return NavigationStack { DashboardView() }
        .environment(env)
        .modelContainer(container)
}
