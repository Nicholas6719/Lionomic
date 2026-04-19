import SwiftUI
import SwiftData

/// The 5-tab root shown after onboarding completes.
/// Each tab wraps its content in its own `NavigationStack` so navigation
/// state is scoped per-tab.
struct TabRoot: View {

    var body: some View {
        TabView {
            NavigationStack { DashboardView() }
                .tabItem { Label("Dashboard", systemImage: "house.fill") }

            NavigationStack { AccountListView() }
                .tabItem { Label("Portfolio", systemImage: "chart.pie.fill") }

            NavigationStack { WatchlistListView() }
                .tabItem { Label("Watchlists", systemImage: "eye.fill") }

            NavigationStack { RecommendationsListView() }
                .tabItem { Label("Insights", systemImage: "lightbulb.fill") }

            NavigationStack { SettingsView() }
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    try? env.watchlistRepository.seedDefaultsIfNeeded()
    return TabRoot()
        .environment(env)
        .modelContainer(container)
}
