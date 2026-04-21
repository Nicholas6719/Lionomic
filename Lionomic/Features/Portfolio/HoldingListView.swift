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
                Section {
                    ForEach(account.holdings.sorted { $0.symbol < $1.symbol }) { holding in
                        HoldingRow(
                            holding: holding,
                            quote: quotes[holding.symbol],
                            hadError: errors.contains(holding.symbol)
                        )
                    }
                } header: {
                    Text("\(account.displayName) · \(account.kind.displayName)")
                        .font(.footnote)
                        .textCase(.uppercase)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
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
        HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 2) {
                Text(holding.symbol)
                    .font(.body.weight(.bold))
                    .foregroundStyle(.primary)
                Text(holding.assetType.displayName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: DesignSystem.Spacing.xs)

            VStack(alignment: .trailing, spacing: 2) {
                marketValueLine
                gainLossLine
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var marketValueLine: some View {
        if let value = marketValue {
            Text(MoneyFormatter.string(from: value))
                .font(.body)
                .foregroundStyle(.primary)
        } else if hadError {
            Text("Quote unavailable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else if holding.assetType.usesMarketQuote {
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("—")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var gainLossLine: some View {
        if let shares = holding.shares,
           let cost = holding.averageCost,
           let quote,
           cost > 0, shares > 0, quote.isFresh {
            let delta = (quote.price - cost) * shares
            let ratio = (quote.price - cost) / cost
            let tint: Color = {
                if delta > 0 { return .gainGreen }
                if delta < 0 { return .lossRed }
                return .secondary
            }()
            Text("\(MoneyFormatter.signedString(from: delta)) (\(PercentFormatter.signedString(from: ratio)))")
                .font(.footnote)
                .foregroundStyle(tint)
        } else {
            Text("—")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    /// Market value = shares × live price for quote-backed holdings;
    /// `manualValuation` for NFTs. Returns `nil` while a quote is loading
    /// or when required inputs are missing.
    private var marketValue: Decimal? {
        if holding.assetType.usesMarketQuote {
            if let shares = holding.shares, let quote {
                return shares * quote.price
            }
            return nil
        } else {
            return holding.manualValuation
        }
    }
}
