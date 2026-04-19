import SwiftUI

/// Display-only status for each market data provider.
/// No live network checks — last-fetch time comes from `CachedQuote` via the MarketDataService.
struct ProviderStatusView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var lastFetchByProvider: [String: Date] = [:]

    var body: some View {
        List {
            Section {
                ProviderStatusRow(
                    providerName: "Twelve Data",
                    role: "Primary provider",
                    isConfigured: env.keychainService.hasValue(
                        for: KeychainService.twelveDataApiKeyIdentifier
                    ),
                    lastFetch: lastFetchByProvider["Twelve Data"]
                )
                ProviderStatusRow(
                    providerName: "Finnhub",
                    role: "Fallback provider",
                    isConfigured: env.keychainService.hasValue(
                        for: KeychainService.finnhubApiKeyIdentifier
                    ),
                    lastFetch: lastFetchByProvider["Finnhub"]
                )
            } footer: {
                Text("Live quotes require at least one configured provider. Last-fetch time is from the on-device quote cache.")
            }
        }
        .navigationTitle("Provider Status")
        .task {
            await loadLastFetchTimes()
        }
    }

    private func loadLastFetchTimes() async {
        let twelveData = await env.marketDataService.mostRecentFetch(by: "Twelve Data")
        let finnhub    = await env.marketDataService.mostRecentFetch(by: "Finnhub")
        if let twelveData { lastFetchByProvider["Twelve Data"] = twelveData }
        if let finnhub    { lastFetchByProvider["Finnhub"]     = finnhub }
    }
}

private struct ProviderStatusRow: View {
    let providerName: String
    let role: String
    let isConfigured: Bool
    let lastFetch: Date?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(providerName)
                    Text(role).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Label(
                    isConfigured ? "Key saved" : "Not configured",
                    systemImage: isConfigured ? "checkmark.circle.fill" : "exclamationmark.circle"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(isConfigured ? .green : .orange)
            }
            if let lastFetch {
                Text("Last fetch: \(lastFetch.formatted(.relative(presentation: .named)))")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            } else if isConfigured {
                Text("No fetches yet")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 2)
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    NavigationStack {
        ProviderStatusView()
            .environment(env)
    }
}
