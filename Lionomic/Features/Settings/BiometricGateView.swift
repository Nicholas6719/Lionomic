import SwiftUI
import LocalAuthentication

/// Full-screen lock overlay. Shown when `BiometricService.isLocked` is true
/// and biometrics are enabled in preferences.
struct BiometricGateView: View {

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                VStack(spacing: 8) {
                    Text("Lionomic is locked")
                        .font(.title2.weight(.semibold))
                    Text("Your portfolio data is protected.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Button {
                    Task { await env.biometricService.authenticate() }
                } label: {
                    Label(unlockLabel, systemImage: unlockIcon)
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(32)
        }
        .transition(.opacity)
    }

    private var unlockLabel: String {
        switch env.biometricService.biometricType {
        case .faceID:  return "Unlock with Face ID"
        case .touchID: return "Unlock with Touch ID"
        default:       return "Unlock with Passcode"
        }
    }

    private var unlockIcon: String {
        switch env.biometricService.biometricType {
        case .faceID:  return "faceid"
        case .touchID: return "touchid"
        default:       return "lock.open"
        }
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    BiometricGateView()
        .environment(env)
}
