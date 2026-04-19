import SwiftUI
import SwiftData

/// The root of the app's view hierarchy.
///
/// M2: BiometricGateView overlay + scenePhase lock-on-background watcher.
/// M3: OnboardingView shown until preferences.firstLaunchComplete flips true.
/// M6: Post-onboarding content is a 5-tab TabView (Dashboard / Portfolio /
///     Watchlists / Insights / Settings).
///
/// The biometric overlay and scenePhase watcher live on the outer body
/// modifiers so they wrap whichever inner content is active.
struct RootView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        Group {
            if env.preferencesRepository.currentPreferences?.firstLaunchComplete == true {
                TabRoot()
            } else if env.preferencesRepository.currentPreferences != nil {
                OnboardingView()
            } else {
                // Preferences not yet loaded — blank screen briefly while seeding runs.
                Color.clear
            }
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
