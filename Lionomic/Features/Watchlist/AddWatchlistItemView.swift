import SwiftUI

/// Sheet: add a new symbol to one of the watchlists.
///
/// Follows the confirm-before-save rule: edit freely, tap Review, then Confirm
/// in the review sheet to commit. Duplicate-symbol errors surface as user-facing
/// alerts, not crashes.
struct AddWatchlistItemView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var viewModel: AddWatchlistItemViewModel

    init(watchlistKind: WatchlistKind) {
        _viewModel = State(initialValue: AddWatchlistItemViewModel(watchlistKind: watchlistKind))
    }

    var body: some View {
        @Bindable var bindableVM = viewModel

        NavigationStack {
            Form {
                Section {
                    TextField("Symbol (e.g. AAPL)", text: $bindableVM.draft.symbol)
                        .textInputAutocapitalization(.characters)
                        .autocorrectionDisabled()

                    Picker("Asset Type", selection: Binding(
                        get: { viewModel.draft.assetType },
                        set: { viewModel.assetTypeChanged(to: $0) }
                    )) {
                        ForEach(AssetType.allCases, id: \.self) {
                            Text($0.displayName).tag($0)
                        }
                    }
                }

                if !viewModel.isNFT {
                    Section {
                        TextField("Target Buy-Below Price (optional)", text: targetBuyBelowBinding)
                            .keyboardType(.decimalPad)
                    } header: {
                        Text("Price Target")
                    } footer: {
                        Text("Alerts can fire when the quote drops below this price. Leave blank to skip.")
                    }
                }

                Section {
                    Toggle("Enable Alerts", isOn: $bindableVM.draft.alertsEnabled)
                } footer: {
                    Text("When on, Lionomic can notify you about movement on this symbol. Notification delivery is wired up in a later milestone.")
                }

                Section {
                    TextField("Notes (optional)", text: $bindableVM.draft.notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Review") { viewModel.showingReview = true }
                        .disabled(!viewModel.canRequestReview)
                }
            }
        }
        .sheet(isPresented: $bindableVM.showingReview) {
            AddWatchlistItemReviewSheet(
                draft: viewModel.draft,
                watchlistKind: viewModel.watchlistKind
            ) {
                do {
                    try env.watchlistRepository.commit(draftItem: viewModel.draft)
                    dismiss()
                } catch {
                    viewModel.errorMessage = errorMessage(for: error)
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

    private var navTitle: String {
        switch viewModel.watchlistKind {
        case .standard:                return "Add to Standard"
        case .highPriorityOpportunity: return "Add to High-Priority"
        }
    }

    private func errorMessage(for error: Error) -> String {
        if let repoError = error as? WatchlistRepositoryError {
            switch repoError {
            case .duplicateSymbolInWatchlist:
                return "That symbol is already on this watchlist."
            case .emptySymbol:
                return "Please enter a symbol."
            case .watchlistNotFound:
                return "Watchlist not found. Try restarting the app."
            case .itemNotFound:
                return "Item no longer exists."
            }
        }
        return error.localizedDescription
    }

    // MARK: - Decimal text binding (parses on every edit)

    private var targetBuyBelowBinding: Binding<String> {
        Binding(
            get: { viewModel.draft.targetBuyBelow.map { "\($0)" } ?? "" },
            set: { viewModel.draft.targetBuyBelow = Decimal(string: $0) }
        )
    }
}

private struct AddWatchlistItemReviewSheet: View {
    let draft: DraftWatchlistItem
    let watchlistKind: WatchlistKind
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Item to add") {
                    LabeledContent("Symbol",    value: Holding.normalize(symbol: draft.symbol))
                    LabeledContent("Asset Type", value: draft.assetType.displayName)
                    LabeledContent("Watchlist",  value: watchlistKind.displayName)
                    if let target = draft.targetBuyBelow {
                        LabeledContent("Buy Below", value: formatCurrency(target))
                    }
                    LabeledContent("Alerts",     value: draft.alertsEnabled ? "On" : "Off")
                    if !draft.notes.trimmingCharacters(in: .whitespaces).isEmpty {
                        LabeledContent("Notes", value: draft.notes)
                    }
                }
                Section {
                    Text("Stored only on this device. Never shared.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review Item")
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

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    AddWatchlistItemView(watchlistKind: .standard)
        .environment(env)
}
