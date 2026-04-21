import SwiftUI

/// A single watchlist row.
///
/// Shows: symbol + asset-kind label (left), current price + signed change
/// (right). Bell icon appears when alerts are enabled; target pill below
/// when set. NFT rows skip the quote fetch and render a manual label.
struct WatchlistItemRow: View {

    let item: WatchlistItem
    let quote: QuoteResult?
    let hadError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: DesignSystem.Spacing.sm) {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(item.symbol)
                            .font(.body.weight(.bold))
                            .foregroundStyle(.primary)
                        if item.alertsEnabled {
                            Image(systemName: "bell.fill")
                                .font(.caption2)
                                .foregroundStyle(Color.lionomicAccent)
                                .accessibilityLabel("Alerts enabled")
                        }
                    }
                    Text(item.assetType.displayName)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: DesignSystem.Spacing.xs)

                VStack(alignment: .trailing, spacing: 2) {
                    priceLine
                    changeLine
                }
            }

            if let target = item.targetBuyBelow, item.assetType.usesMarketQuote {
                Text("Target: buy below \(MoneyFormatter.string(from: target))")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var priceLine: some View {
        if !item.assetType.usesMarketQuote {
            Text("Manual")
                .font(.body)
                .foregroundStyle(.secondary)
        } else if let quote {
            Text(MoneyFormatter.string(from: quote.price))
                .font(.body)
                .foregroundStyle(.primary)
        } else if hadError {
            Text("Quote unavailable")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("Loading…")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var changeLine: some View {
        if let quote, item.assetType.usesMarketQuote,
           quote.change != 0 || quote.changePercent != 0 {
            Text("\(MoneyFormatter.signedString(from: quote.change)) (\(PercentFormatter.signedString(from: quote.changePercent)))")
                .font(.footnote)
                .foregroundStyle(changeColor(for: quote.change))
        } else if item.assetType.usesMarketQuote, quote != nil {
            Text("—")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func changeColor(for value: Decimal) -> Color {
        if value > 0 { return .gainGreen }
        if value < 0 { return .lossRed }
        return .secondary
    }
}
