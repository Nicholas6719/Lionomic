import SwiftUI

/// A single watchlist row.
///
/// Shows: symbol, asset type badge, live price, change / %change, alerts indicator,
/// target-buy-below pill when set. NFT rows render only symbol + asset badge +
/// optional valuation note — no quote fetch.
///
/// Matches the loading / fresh / stale / error state pattern used by `HoldingListView`.
struct WatchlistItemRow: View {

    let item: WatchlistItem
    let quote: QuoteResult?
    let hadError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header line: symbol + badges
            HStack(spacing: 8) {
                Text(item.symbol).font(.headline)

                if item.alertsEnabled {
                    Image(systemName: "bell.fill")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                        .accessibilityLabel("Alerts enabled")
                }

                Spacer()

                Text(item.assetType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(.quaternary, in: Capsule())
            }

            // Quote line (non-NFT) or static label (NFT)
            quoteLine

            // Target pill — only meaningful for symbols with live quotes
            if let target = item.targetBuyBelow, item.assetType.usesMarketQuote {
                Text("Target: buy below \(formatCurrency(target))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var quoteLine: some View {
        if !item.assetType.usesMarketQuote {
            Text("Manual valuation only — no live quote.")
                .font(.caption)
                .foregroundStyle(.tertiary)
        } else if let quote {
            HStack(spacing: 8) {
                Text(formatCurrency(quote.price))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)

                if quote.change != 0 || quote.changePercent != 0 {
                    Text(formatChange(quote.change))
                        .font(.caption)
                        .foregroundStyle(changeColor(for: quote.change))
                    Text(formatPercent(quote.changePercent))
                        .font(.caption)
                        .foregroundStyle(changeColor(for: quote.change))
                }

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
                .font(.caption)
                .foregroundStyle(.orange)
        } else {
            Text("Loading quote…")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: - Formatting

    private func changeColor(for value: Decimal) -> Color {
        if value > 0 { return .green }
        if value < 0 { return .red }
        return .secondary
    }

    private func formatCurrency(_ value: Decimal) -> String { MoneyFormatter.string(from: value) }
    private func formatChange(_ value: Decimal) -> String   { MoneyFormatter.signedString(from: value) }
    private func formatPercent(_ ratio: Decimal) -> String  { PercentFormatter.signedString(from: ratio) }
}
