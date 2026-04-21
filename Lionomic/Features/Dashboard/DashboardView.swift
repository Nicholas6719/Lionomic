import SwiftUI
import SwiftData

/// The Dashboard tab. A vertically-scrollable stack of four cards:
/// `PortfolioSummaryCard`, `WatchlistHighlightsCard`, `MorningBriefCard`,
/// and `RecommendationsCard`. Each card owns its own load/empty/populated
/// state and uses the shared `DashboardCard` wrapper for a consistent look.
struct DashboardView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.sm) {
                PortfolioSummaryCard()
                WatchlistHighlightsCard()
                MorningBriefCard()
                RecommendationsCard()
            }
            .padding(.horizontal, DesignSystem.Spacing.md)
            .padding(.vertical, DesignSystem.Spacing.md)
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
