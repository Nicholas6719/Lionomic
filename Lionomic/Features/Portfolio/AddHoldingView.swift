import SwiftUI

struct AddHoldingView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddHoldingViewModel

    init(account: Account) {
        _viewModel = State(initialValue: AddHoldingViewModel(account: account))
    }

    var body: some View {
        @Bindable var bindableVM = viewModel

        NavigationStack {
            Form {
                // Symbol + asset type
                Section {
                    TextField("Symbol (e.g. AAPL)", text: $bindableVM.draft.symbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker("Asset Type", selection: $bindableVM.draft.assetType) {
                        ForEach(AssetType.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                }

                // Non-NFT fields
                if !viewModel.isNFT {
                    Section {
                        TextField("Shares", text: sharesBinding)
                            .keyboardType(.decimalPad)
                        TextField("Average Cost per Share", text: averageCostBinding)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("Position")
                    } footer: {
                        Text("Use your average cost basis, not current price.")
                    }
                }

                // NFT fields
                if viewModel.isNFT {
                    Section {
                        TextField("Manual Valuation (USD)", text: manualValuationBinding)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("NFT Valuation")
                    } footer: {
                        Text("NFT pricing is manual only. Enter your best current estimate.")
                    }
                }

                // Notes
                Section {
                    TextField("Notes (optional)", text: $bindableVM.draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle("Add Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") { viewModel.showingReview = true }
                        .disabled(!viewModel.canRequestReview)
                }
            }
        }
        .sheet(isPresented: $bindableVM.showingReview) {
            AddHoldingReviewSheet(
                draft: viewModel.draft,
                account: viewModel.account
            ) {
                do {
                    let holding = try env.portfolioRepository.commit(
                        draftHolding: viewModel.draft
                    )
                    env.historyService.snapshotHolding(holding)
                    env.historyService.snapshotAccount(viewModel.account)
                    dismiss()
                } catch {
                    viewModel.errorMessage = error.localizedDescription
                    viewModel.showingReview = false
                }
            }
        }
        .alert("Could not save", isPresented: .init(
            get: { viewModel.errorMessage != nil },
            set: { if !$0 { viewModel.errorMessage = nil } }
        )) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            if let msg = viewModel.errorMessage { Text(msg) }
        }
    }

    // MARK: - Decimal text bindings
    // Decimal fields are edited as strings and parsed on commit.

    private var sharesBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.shares.map { "\($0)" } ?? "" },
            set: { viewModel.draft.shares = Decimal(string: $0) }
        )
    }

    private var averageCostBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.averageCost.map { "\($0)" } ?? "" },
            set: { viewModel.draft.averageCost = Decimal(string: $0) }
        )
    }

    private var manualValuationBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.manualValuation.map { "\($0)" } ?? "" },
            set: { viewModel.draft.manualValuation = Decimal(string: $0) }
        )
    }
}

private struct AddHoldingReviewSheet: View {
    let draft: DraftHolding
    let account: Account
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Holding to add") {
                    LabeledContent("Symbol",     value: draft.symbol)
                    LabeledContent("Asset Type", value: draft.assetType.displayName)
                    LabeledContent("Account",    value: account.displayName)
                    if let shares = draft.shares {
                        LabeledContent("Shares", value: "\(shares)")
                    }
                    if let cost = draft.averageCost {
                        LabeledContent("Avg Cost", value: formatCurrency(cost))
                    }
                    if let valuation = draft.manualValuation {
                        LabeledContent("Valuation", value: formatCurrency(valuation))
                    }
                    if !draft.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        LabeledContent("Notes", value: draft.notes)
                    }
                }
                Section {
                    Text("Stored only on this device. Never shared.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review Holding")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirm") { onConfirm() } }
            }
        }
        .presentationDetents([.medium])
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }
}
