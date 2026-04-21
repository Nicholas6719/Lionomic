import SwiftUI
import SwiftData

/// The root TabView shown after onboarding completes. 5 tabs ship in V1,
/// plus an optional 6th Chat tab gated on `AppPreferences.chatEnabled`.
///
/// When `chatEnabled == false` the Chat tab is not emitted into the view
/// hierarchy at all — it cannot be reached by swipe, keyboard, or state
/// restoration. Flipping the flag at runtime adds the tab without any
/// other wiring change.
///
/// Each tab wraps its content in its own `NavigationStack` so navigation
/// state is scoped per-tab.
struct TabRoot: View {

    @Environment(AppEnvironment.self) private var env

    private var chatEnabled: Bool {
        env.preferencesRepository.currentPreferences?.chatEnabled == true
    }

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

            if chatEnabled {
                NavigationStack {
                    ChatView(viewModel: ChatViewModel(
                        aiService: env.aiService,
                        profileRepository: env.profileRepository,
                        portfolioRepository: env.portfolioRepository,
                        watchlistRepository: env.watchlistRepository
                    ))
                }
                .tabItem { Label("Chat", systemImage: "message") }
            }
        }
        .tint(Color.lionomicAccent)
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
