import Foundation
import LocalAuthentication

/// Tracks whether the app is locked and handles biometric/passcode authentication.
///
/// Lock behavior:
///   - `isLocked` starts `true` at every cold launch.
///   - `RootView` calls `lock()` when `scenePhase` transitions to `.background`.
///   - `RootView` calls `authenticate()` when the app returns to `.active`.
///   - `.deviceOwnerAuthentication` means Face ID / Touch ID → passcode automatic fallback.
@Observable
final class BiometricService {

    private(set) var isLocked: Bool = true
    private(set) var biometricType: LABiometryType = .none

    init() {
        refreshBiometricType()
    }

    func refreshBiometricType() {
        let context = LAContext()
        var error: NSError?
        _ = context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
        biometricType = context.biometryType
    }

    func authenticate() async {
        let context = LAContext()
        do {
            let success = try await context.evaluatePolicy(
                .deviceOwnerAuthentication,
                localizedReason: "Unlock Lionomic to view your portfolio."
            )
            if success { isLocked = false }
        } catch {
            // User cancelled or failed — stay locked, let them retry.
        }
    }

    func lock() {
        isLocked = true
    }

    /// Unlocks without authentication. Used when the user disables biometrics in Settings.
    func unlockWithoutAuthentication() {
        isLocked = false
    }
}
