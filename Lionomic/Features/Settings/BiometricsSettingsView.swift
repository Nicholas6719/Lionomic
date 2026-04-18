import SwiftUI
import LocalAuthentication

/// Lets the user enable or disable the biometric lock screen.
/// All changes go through a review sheet before being committed.
struct BiometricsSettingsView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var pendingDraft: DraftPreferences?
    @State private var showingReviewSheet = false
    @State private var errorMessage: String?

    var body: some View {
        List {
            Section {
                Toggle(isOn: biometricsBinding) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Require Authentication")
                        Text(biometricCapabilityNote)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } footer: {
                Text("When on, Lionomic locks every time you leave the app and requires Face ID, Touch ID, or your passcode to return.")
            }
        }
        .navigationTitle("Biometrics")
        .sheet(isPresented: $showingReviewSheet) {
            if let draft = pendingDraft {
                BiometricsReviewSheet(draft: draft) {
                    try env.preferencesRepository.commit(draft: draft)
                    if !draft.biometricsEnabled {
                        env.biometricService.unlockWithoutAuthentication()
                    }
                    showingReviewSheet = false
                }
            }
        }
        .alert("Could not save", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    private var biometricsBinding: Binding<Bool> {
        Binding(
            get: {
                env.preferencesRepository.currentPreferences?.biometricsEnabled ?? true
            },
            set: { newValue in
                guard let existing = env.preferencesRepository.currentPreferences else { return }
                var draft = DraftPreferences(editing: existing)
                draft.biometricsEnabled = newValue
                pendingDraft = draft
                showingReviewSheet = true
            }
        )
    }

    private var biometricCapabilityNote: String {
        switch env.biometricService.biometricType {
        case .faceID:  return "Face ID available on this device"
        case .touchID: return "Touch ID available on this device"
        default:       return "Passcode only — no biometric sensor detected"
        }
    }
}

// MARK: - Review sheet

private struct BiometricsReviewSheet: View {
    let draft: DraftPreferences
    let onConfirm: () throws -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            List {
                Section("Review Change") {
                    LabeledContent("Authentication required") {
                        Text(draft.biometricsEnabled ? "On" : "Off")
                            .foregroundStyle(draft.biometricsEnabled ? .primary : .secondary)
                    }
                }
                Section {
                    Text(draft.biometricsEnabled
                        ? "The app will require Face ID, Touch ID, or passcode each time you open it."
                        : "Anyone with physical access to this device will be able to open the app without authentication.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }
                if let message = errorMessage {
                    Section {
                        Text(message).font(.caption).foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Confirm")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        do { try onConfirm() }
                        catch { errorMessage = error.localizedDescription }
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    NavigationStack {
        BiometricsSettingsView()
            .environment(env)
    }
}
