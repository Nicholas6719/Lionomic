import SwiftUI

/// Top-level Settings screen. Since M6 it is the root of the Settings tab —
/// no longer presented as a sheet, so there is no Done button.
struct SettingsView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var showingResetStage1 = false
    @State private var showingResetStage2 = false

    var body: some View {
        List {
            Section("Preferences") {
                NavigationLink {
                    EditProfileView()
                } label: {
                    Label("Investing Profile", systemImage: "person.crop.circle")
                }

                NavigationLink {
                    EditPreferencesView()
                } label: {
                    Label("App Preferences", systemImage: "slider.horizontal.3")
                }
            }

            Section("Security") {
                NavigationLink {
                    BiometricsSettingsView()
                } label: {
                    Label("Biometrics & Lock", systemImage: "faceid")
                }
            }

            Section("Market Data") {
                NavigationLink {
                    ApiKeysView()
                } label: {
                    Label("API Keys", systemImage: "key.fill")
                }

                NavigationLink {
                    ProviderStatusView()
                } label: {
                    Label("Provider Status", systemImage: "antenna.radiowaves.left.and.right")
                }
            }

            Section("About") {
                LabeledContent("Version", value: appVersion)
            }

            Section("Danger Zone") {
                Button(role: .destructive) {
                    showingResetStage1 = true
                } label: {
                    Label("Reset All Data", systemImage: "trash")
                }
            }
        }
        .navigationTitle("Settings")
        .confirmationDialog(
            "Reset all data?",
            isPresented: $showingResetStage1,
            titleVisibility: .visible
        ) {
            Button("Continue…", role: .destructive) {
                showingResetStage2 = true
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your portfolio data, accounts, holdings, watchlist items, and preferences. This cannot be undone.")
        }
        .alert("Are you sure?", isPresented: $showingResetStage2) {
            Button("Reset Everything", role: .destructive) {
                env.resetAllData()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This is the final confirmation. Your local data will be erased and you will be returned to onboarding.")
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    SettingsView()
        .environment(env)
}
