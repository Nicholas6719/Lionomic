import SwiftUI

struct AccountListView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [Account] = []
    @State private var showingAddAccount = false
    @State private var overrideSheetAccount: Account?

    var body: some View {
        List {
            if accounts.isEmpty {
                ContentUnavailableView(
                    "No Accounts",
                    systemImage: "building.columns",
                    description: Text("Add an account to start tracking your portfolio.")
                )
            } else {
                ForEach(accounts) { account in
                    NavigationLink {
                        HoldingListView(account: account)
                    } label: {
                        AccountRow(
                            account: account,
                            hasOverride: env.profileRepository.override(for: account) != nil
                        )
                    }
                    .contextMenu {
                        Button {
                            overrideSheetAccount = account
                        } label: {
                            Label("Account Overrides", systemImage: "slider.horizontal.3")
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Portfolio")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddAccount = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Account")
            }
        }
        .task { loadAccounts() }
        .sheet(isPresented: $showingAddAccount, onDismiss: loadAccounts) {
            AddAccountView()
        }
        .sheet(item: $overrideSheetAccount, onDismiss: loadAccounts) { account in
            AccountOverrideSheet(account: account)
        }
    }

    private func loadAccounts() {
        accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
    }
}

private struct AccountRow: View {
    let account: Account
    let hasOverride: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(account.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(account.kind.displayName)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if hasOverride {
                // MProfile: subtle accent-tint dot signalling this account
                // has custom profile overrides applied. Accessible label
                // makes it readable by VoiceOver.
                Circle()
                    .fill(Color.lionomicAccent)
                    .frame(width: 8, height: 8)
                    .accessibilityLabel("Account has custom profile overrides")
            }
        }
        .padding(.vertical, 4)
    }
}
