import SwiftUI
import SwiftData

/// The root of the app's view hierarchy.
///
/// M2 additions:
///   - BiometricGateView overlay (appears when locked + biometrics enabled)
///   - Locks on background, auto-triggers auth on foreground return
///   - Settings toolbar button
///
/// M3 additions:
///   - OnboardingView shown until preferences.firstLaunchComplete flips true
///
/// The placeholder content is replaced in M6 with the tab bar.
struct RootView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            Group {
                if env.preferencesRepository.currentPreferences?.firstLaunchComplete == true {
                    // M0 placeholder — replaced in M6 with tab bar
                    VStack(spacing: 12) {
                        Text("Lionomic")
                            .font(.largeTitle.weight(.bold))
                        Text("Your private investing guide.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if env.preferencesRepository.currentPreferences != nil {
                    // Preferences loaded but onboarding not complete — show onboarding
                    OnboardingView()
                } else {
                    // Preferences not yet loaded — blank screen briefly while seeding runs
                    Color.clear
                }
            }
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
