import SwiftUI

/// Top-level Settings screen, presented as a sheet from RootView.
struct SettingsView: View {

    @Environment(\.dismiss) private var dismiss
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        NavigationStack {
            List {
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
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
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
