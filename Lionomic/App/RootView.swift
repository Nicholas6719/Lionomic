import SwiftUI
import SwiftData

/// The root of the app's view hierarchy.
///
/// M2 additions:
///   - BiometricGateView overlay (appears when locked + biometrics enabled)
///   - Locks on background, auto-triggers auth on foreground return
///   - Settings toolbar button
///
/// The placeholder content is replaced in M6 with the tab bar.
struct RootView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 12) {
                Text("Lionomic")
                    .font(.largeTitle.weight(.semibold))
                Text("Private, local-first investing guidance")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .overlay {
            let biometricsEnabled = env.preferencesRepository.currentPreferences?.biometricsEnabled ?? true
            if env.biometricService.isLocked && biometricsEnabled {
                BiometricGateView()
                    .transition(.opacity)
                    .animation(.easeInOut(duration: 0.2), value: env.biometricService.isLocked)
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            let biometricsEnabled = env.preferencesRepository.currentPreferences?.biometricsEnabled ?? true
            guard biometricsEnabled else { return }

            switch newPhase {
            case .background:
                env.biometricService.lock()
            case .active:
                if env.biometricService.isLocked {
                    Task { await env.biometricService.authenticate() }
                }
            default:
                break
            }
        }
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    RootView()
        .environment(AppEnvironment(modelContainer: container))
        .modelContainer(container)
}
