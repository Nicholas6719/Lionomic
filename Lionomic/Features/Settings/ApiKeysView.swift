import SwiftUI

/// Entry point for Twelve Data and Finnhub API keys.
/// Keys are written to the Keychain only after user review and confirmation.
struct ApiKeysView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var viewModel = ApiKeysViewModel()

    var body: some View {
        // @Bindable lets us pass $viewModel.showingReviewSheet to .sheet().
        @Bindable var bindableVM = viewModel

        List {
            Section {
                ApiKeyEntryRow(
                    providerName: "Twelve Data",
                    keyIsSaved: viewModel.twelveDataKeyIsSaved,
                    draftKey: $bindableVM.draftTwelveDataKey,
                    onDelete: { viewModel.deleteTwelveDataKey() }
                )
            } header: {
                Text("Primary Provider")
            } footer: {
                Text("Used for live stock, ETF, and fund quotes. Free key at twelvedata.com.")
            }

            Section {
                ApiKeyEntryRow(
                    providerName: "Finnhub",
                    keyIsSaved: viewModel.finnhubKeyIsSaved,
                    draftKey: $bindableVM.draftFinnhubKey,
                    onDelete: { viewModel.deleteFinnhubKey() }
                )
            } header: {
                Text("Fallback Provider")
            } footer: {
                Text("Used when Twelve Data is unavailable or rate-limited. Free key at finnhub.io.")
            }

            Section {
                Button("Review and Save Keys") {
                    viewModel.requestReview()
                }
                .disabled(!viewModel.canRequestReview)
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .navigationTitle("API Keys")
        .task {
            viewModel.configure(keychain: env.keychainService)
        }
        .sheet(isPresented: $bindableVM.showingReviewSheet) {
            ApiKeysReviewSheet(viewModel: viewModel)
        }
    }
}

// MARK: - Key entry row

private struct ApiKeyEntryRow: View {
    let providerName: String
    let keyIsSaved: Bool
    @Binding var draftKey: String
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: keyIsSaved ? "checkmark.circle.fill" : "exclamationmark.circle")
                    .foregroundStyle(keyIsSaved ? .green : .orange)
                Text(keyIsSaved ? "Key saved" : "No key saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                if keyIsSaved {
                    Button(role: .destructive, action: onDelete) {
                        Text("Remove").font(.caption)
                    }
                }
            }
            SecureField("Paste \(providerName) API key…", text: $draftKey)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Review sheet

private struct ApiKeysReviewSheet: View {
    let viewModel: ApiKeysViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Keys to be saved") {
                    let trimmedTD = viewModel.draftTwelveDataKey.trimmingCharacters(in: .whitespaces)
                    let trimmedFH = viewModel.draftFinnhubKey.trimmingCharacters(in: .whitespaces)
                    if !trimmedTD.isEmpty {
                        LabeledContent("Twelve Data", value: maskedKey(trimmedTD))
                    }
                    if !trimmedFH.isEmpty {
                        LabeledContent("Finnhub", value: maskedKey(trimmedFH))
                    }
                }
                Section {
                    Text("Keys are stored in your device Keychain. They are never uploaded, synced, or shared.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Review Keys")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { viewModel.confirmSave() }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func maskedKey(_ key: String) -> String {
        guard key.count > 4 else { return String(repeating: "•", count: key.count) }
        return "\(key.prefix(4))••••••••"
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    NavigationStack {
        ApiKeysView()
            .environment(env)
    }
}
