import SwiftUI

struct AddAccountView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DraftAccount()
    @State private var showingReview = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Account Type", selection: $draft.kind) {
                        ForEach(AccountKind.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                    TextField("Display Name", text: $draft.displayName)
                        .autocorrectionDisabled()
                    TextField("Notes (optional)", text: $draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("New Account")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") { showingReview = true }
                        .disabled(draft.displayName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .sheet(isPresented: $showingReview) {
            AddAccountReviewSheet(draft: draft) {
                do {
                    try env.portfolioRepository.commit(draftAccount: draft)
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

private struct AddAccountReviewSheet: View {
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
                    Text("Stored only on this device.")
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
