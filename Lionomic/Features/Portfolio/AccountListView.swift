import SwiftUI

struct AccountListView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [Account] = []
    @State private var showingAddAccount = false

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
                        AccountRow(account: account)
                    }
                }
            }
        }
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
    }

    private func loadAccounts() {
        accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
    }
}

private struct AccountRow: View {
    let account: Account

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(account.displayName).font(.headline)
            Text("\(account.holdings.count) holding\(account.holdings.count == 1 ? "" : "s")")
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
