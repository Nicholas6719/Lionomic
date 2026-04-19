import SwiftUI

/// Settings → Investing Profile editor.
/// Pre-populates from the stored profile; follows draft/review/confirm.
struct EditProfileView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DraftProfile()
    @State private var showingReview = false
    @State private var errorMessage: String?
    @State private var loaded = false

    var body: some View {
        Form {
            Section {
                Picker("Risk Tolerance", selection: $draft.riskTolerance) {
                    ForEach(RiskTolerance.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Investment Horizon", selection: $draft.horizonPreference) {
                    ForEach(HorizonPreference.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Concentration Sensitivity", selection: $draft.concentrationSensitivity) {
                    ForEach(ConcentrationSensitivity.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Caution Bias", selection: $draft.cautionBias) {
                    ForEach(CautionBias.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Toggle("Prefer Buying Dips", isOn: $draft.preferDipBuying)
            } footer: {
                Text("Your profile shapes recommendations. Update it anytime.")
            }
        }
        .navigationTitle("Investing Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Review") { showingReview = true }
            }
        }
        .task {
            if !loaded {
                if let existing = try? env.profileRepository.fetchProfile() {
                    draft = DraftProfile(from: existing)
                }
                loaded = true
            }
        }
        .sheet(isPresented: $showingReview) {
            EditProfileReviewSheet(draft: draft) {
                do {
                    try env.profileRepository.commit(draft: draft)
                    showingReview = false
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showingReview = false
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
}

private struct EditProfileReviewSheet: View {
    let draft: DraftProfile
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Your investing profile") {
                    LabeledContent("Risk Tolerance",            value: draft.riskTolerance.displayName)
                    LabeledContent("Investment Horizon",        value: draft.horizonPreference.displayName)
                    LabeledContent("Concentration Sensitivity", value: draft.concentrationSensitivity.displayName)
                    LabeledContent("Caution Bias",              value: draft.cautionBias.displayName)
                    LabeledContent("Prefer Buying Dips",        value: draft.preferDipBuying ? "Yes" : "No")
                }
            }
            .navigationTitle("Review Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirm") { onConfirm() } }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    NavigationStack { EditProfileView() }
        .environment(env)
}
