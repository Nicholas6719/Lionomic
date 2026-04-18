import SwiftUI

struct OnboardingProfileView: View {

    let viewModel: OnboardingViewModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var bindableVM = viewModel

        Form {
            Section {
                Picker("Risk Tolerance", selection: $bindableVM.draftProfile.riskTolerance) {
                    ForEach(RiskTolerance.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Investment Horizon", selection: $bindableVM.draftProfile.horizonPreference) {
                    ForEach(HorizonPreference.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Concentration Sensitivity", selection: $bindableVM.draftProfile.concentrationSensitivity) {
                    ForEach(ConcentrationSensitivity.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Picker("Caution Bias", selection: $bindableVM.draftProfile.cautionBias) {
                    ForEach(CautionBias.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                Toggle("Prefer Buying Dips", isOn: $bindableVM.draftProfile.preferDipBuying)
            } header: {
                Text("About Your Investing Style")
            } footer: {
                Text("Personalises your recommendations. You can update this anytime in Settings.")
            }
        }
        .navigationTitle("Your Profile")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Review") { viewModel.requestProfileReview() }
            }
        }
        .sheet(isPresented: $bindableVM.showingProfileReview) {
            ProfileReviewSheet(draft: viewModel.draftProfile) {
                do {
                    try env.profileRepository.commit(draft: viewModel.draftProfile)
                    viewModel.showingProfileReview = false
                    viewModel.stage = .account
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct ProfileReviewSheet: View {
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
