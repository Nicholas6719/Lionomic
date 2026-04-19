import SwiftUI

/// Dashboard card: first 3 items from the high-priority opportunity watchlist
/// with live quote data.
struct WatchlistHighlightsCard: View {

    @Environment(AppEnvironment.self) private var env
    @State private var items: [WatchlistItem] = []
    @State private var quotes: [String: QuoteResult] = [:]

    var body: some View {
        DashboardCard(title: "High-Priority Watchlist", systemImage: "star.fill") {
            if items.isEmpty {
                ContentUnavailableView {
                    Label("No opportunities yet", systemImage: "star")
                } description: {
                    Text("Add symbols to your high-priority watchlist to see them here.")
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(items.prefix(3)) { item in
                        HighlightRow(item: item, quote: quotes[item.symbol])
                        if item.id != items.prefix(3).last?.id {
                            Divider()
                        }
                    }
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        let all = (try? env.watchlistRepository.fetchItems(in: .highPriorityOpportunity)) ?? []
        items = Array(all.prefix(3))
        for item in items where item.assetType.usesMarketQuote {
            if let cached = await env.marketDataService.cachedQuote(for: item.symbol) {
                quotes[item.symbol] = cached
            } else {
                if let fresh = try? await env.marketDataService.fetchQuote(symbol: item.symbol) {
                    quotes[item.symbol] = fresh
                }
            }
        }
    }
}

private struct HighlightRow: View {
    let item: WatchlistItem
    let quote: QuoteResult?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(item.symbol)
                    .font(.subheadline.weight(.semibold))
                Text(item.assetType.displayName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if !item.assetType.usesMarketQuote {
                Text("Manual")
                    .font(.caption).foregroundStyle(.tertiary)
            } else if let quote {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(MoneyFormatter.string(from: quote.price))
                        .font(.subheadline.weight(.medium))
                    if quote.change != 0 || quote.changePercent != 0 {
                        Text(PercentFormatter.signedString(from: quote.changePercent))
                            .font(.caption2)
                            .foregroundStyle(color(for: quote.change))
                    }
                }
            } else {
                Text("…")
                    .font(.caption).foregroundStyle(.tertiary)
            }
        }
    }

    private func color(for change: Decimal) -> Color {
        if change > 0 { return .green }
        if change < 0 { return .red }
        return .secondary
    }
}
