import SwiftUI

/// Dashboard card: total estimated portfolio value plus per-account breakdown.
///
/// Values blend cost basis and fresh live quotes via `PortfolioValuation`.
/// On appear, fetches a fresh cached quote for every non-NFT symbol — uses
/// `cachedQuote(for:)` (no network) first; only misses trigger a real fetch.
struct PortfolioSummaryCard: View {

    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [Account] = []
    @State private var freshQuotes: [String: QuoteResult] = [:]
    @State private var hasLoaded = false

    var body: some View {
        DashboardCard(title: "Portfolio", systemImage: "chart.pie.fill") {
            content
        }
        .task {
            await reload()
        }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            // M11 consistency: show a ProgressView during the initial load
            // so the card doesn't briefly flash the empty state before
            // `reload()` fills in the accounts.
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 16)
        } else if accounts.isEmpty {
            ContentUnavailableView {
                Label("No accounts yet", systemImage: "building.columns")
            } description: {
                Text("Add an account in the Portfolio tab to start tracking.")
            } actions: {
                // Tab-switching from a dashboard card is a future enhancement.
                EmptyView()
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            let totals = PortfolioValuation.totals(for: accounts, quoteFor: { freshQuotes[$0] })
            VStack(alignment: .leading, spacing: 10) {
                Text("Total Value")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(MoneyFormatter.string(from: totals.total))
                    .font(.system(size: 32, weight: .semibold, design: .rounded))
                    .contentTransition(.numericText())

                Divider().padding(.vertical, 4)

                ForEach(totals.breakdown) { row in
                    HStack {
                        Text(row.displayName)
                            .font(.subheadline)
                        Spacer()
                        Text(MoneyFormatter.string(from: row.total))
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func reload() async {
        defer { hasLoaded = true }
        accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
        let symbols = accounts
            .flatMap { $0.holdings }
            .filter { $0.assetType.usesMarketQuote }
            .map(\.symbol)
        let unique = Array(Set(symbols))
        for symbol in unique {
            // Fresh cached only — dashboard doesn't blow through rate limits on render.
            if let cached = await env.marketDataService.cachedQuote(for: symbol), cached.isFresh {
                freshQuotes[symbol] = cached
            }
        }
    }
}
