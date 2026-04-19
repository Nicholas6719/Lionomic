import SwiftUI

struct HoldingListView: View {

    @Environment(AppEnvironment.self) private var env
    let account: Account
    @State private var showingAddHolding = false
    @State private var quotes: [String: QuoteResult] = [:]
    @State private var errors: Set<String> = []

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
                    HoldingRow(
                        holding: holding,
                        quote: quotes[holding.symbol],
                        hadError: errors.contains(holding.symbol)
                    )
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
        .task(id: account.id) {
            await loadQuotes()
        }
    }

    private func loadQuotes() async {
        for holding in account.holdings where holding.assetType.usesMarketQuote {
            let symbol = holding.symbol
            do {
                let quote = try await env.marketDataService.fetchQuote(symbol: symbol)
                quotes[symbol] = quote
                errors.remove(symbol)
            } catch {
                errors.insert(symbol)
            }
        }
    }
}

private struct HoldingRow: View {
    let holding: Holding
    let quote: QuoteResult?
    let hadError: Bool

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

            // Cost-basis / valuation line
            if let shares = holding.shares, let cost = holding.averageCost {
                Text("\(formatDecimal(shares)) shares @ \(formatCurrency(cost))")
                    .font(.caption).foregroundStyle(.secondary)
            } else if let valuation = holding.manualValuation {
                Text("Manual valuation: \(formatCurrency(valuation))")
                    .font(.caption).foregroundStyle(.secondary)
            }

            // Live quote line (non-NFT only)
            quoteLine
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var quoteLine: some View {
        if !holding.assetType.usesMarketQuote {
            // NFT — no fetch attempted.
            EmptyView()
        } else if let quote {
            HStack(spacing: 6) {
                Text(formatCurrency(quote.price))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                if !quote.isFresh {
                    Text("stale")
                        .font(.caption2)
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("via \(quote.providerName)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        } else if hadError {
            Text("Quote unavailable")
                .font(.caption).foregroundStyle(.orange)
        } else {
            Text("Loading quote…")
                .font(.caption).foregroundStyle(.tertiary)
        }
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
