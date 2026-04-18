import SwiftUI

struct HoldingListView: View {

    @Environment(AppEnvironment.self) private var env
    let account: Account
    @State private var showingAddHolding = false

    var body: some View {
        List {
            if account.holdings.isEmpty {
                ContentUnavailableView(
                    "No Holdings",
                    systemImage: "chart.pie",
                    description: Text("Tap + to add your first holding.")
                )
            } else {
                ForEach(account.holdings.sorted { $0.symbol < $1.symbol }) { holding in
                    HoldingRow(holding: holding)
                }
            }
        }
        .navigationTitle(account.displayName)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { showingAddHolding = true } label: {
                    Image(systemName: "plus")
                }
                .accessibilityLabel("Add Holding")
            }
        }
        .sheet(isPresented: $showingAddHolding) {
            AddHoldingView(account: account)
        }
    }
}

private struct HoldingRow: View {
    let holding: Holding

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(holding.symbol).font(.headline)
                Spacer()
                Text(holding.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }
            if let shares = holding.shares, let cost = holding.averageCost {
                Text("\(formatDecimal(shares)) shares @ \(formatCurrency(cost))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let valuation = holding.manualValuation {
                Text("Manual valuation: \(formatCurrency(valuation))")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private func formatCurrency(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "USD"
        return f.string(from: value as NSDecimalNumber) ?? "$\(value)"
    }

    private func formatDecimal(_ value: Decimal) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 6
        return f.string(from: value as NSDecimalNumber) ?? "\(value)"
    }
}
