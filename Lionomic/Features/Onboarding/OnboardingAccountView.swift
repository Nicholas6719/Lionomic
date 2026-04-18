import SwiftUI

struct OnboardingAccountView: View {

    let viewModel: OnboardingViewModel
    @Environment(AppEnvironment.self) private var env

    var body: some View {
        @Bindable var bindableVM = viewModel

        Form {
            Section {
                Picker("Account Type", selection: $bindableVM.draftAccount.kind) {
                    ForEach(AccountKind.allCases, id: \.self) {
                        Text($0.displayName).tag($0)
                    }
                }
                TextField("Display Name", text: $bindableVM.draftAccount.displayName)
                    .autocorrectionDisabled()
                TextField("Notes (optional)", text: $bindableVM.draftAccount.notes, axis: .vertical)
                    .lineLimit(2...4)
            } header: {
                Text("Add Your First Account")
            } footer: {
                Text("V1 supports a Roth IRA and a brokerage account. Add more after setup.")
            }
        }
        .navigationTitle("First Account")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Review") { viewModel.requestAccountReview() }
                    .disabled(viewModel.draftAccount.displayName
                        .trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .sheet(isPresented: $bindableVM.showingAccountReview) {
            AccountReviewSheet(draft: viewModel.draftAccount) {
                do {
                    try env.portfolioRepository.commit(draftAccount: viewModel.draftAccount)
                    viewModel.showingAccountReview = false
                    viewModel.onFinished()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                }
            }
        }
    }
}

private struct AccountReviewSheet: View {
    let draft: DraftAccount
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Account to create") {
                    LabeledContent("Type",         value: draft.kind.displayName)
                    LabeledContent("Display Name", value: draft.displayName)
                    if !draft.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        LabeledContent("Notes", value: draft.notes)
                    }
                }
                Section {
                    Text("Stored only on this device. Never shared.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirm") { onConfirm() } }
            }
        }
        .presentationDetents([.medium])
    }
}
