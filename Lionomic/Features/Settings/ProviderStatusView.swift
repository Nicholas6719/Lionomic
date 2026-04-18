import SwiftUI

/// Display-only stub showing whether each market data provider has a key saved.
/// Live provider health checks are introduced in M4.
struct ProviderStatusView: View {

    @Environment(AppEnvironment.self) private var env

    var body: some View {
        List {
            Section {
                ProviderStatusRow(
                    providerName: "Twelve Data",
                    role: "Primary provider",
                    isConfigured: env.keychainService.hasValue(
                        for: KeychainService.twelveDataApiKeyIdentifier
                    )
                )
                ProviderStatusRow(
                    providerName: "Finnhub",
                    role: "Fallback provider",
                    isConfigured: env.keychainService.hasValue(
                        for: KeychainService.finnhubApiKeyIdentifier
                    )
                )
            } footer: {
                Text("Live quotes require at least one configured provider. Market data activates in M4.")
            }
        }
        .navigationTitle("Provider Status")
    }
}

private struct ProviderStatusRow: View {
    let providerName: String
    let role: String
    let isConfigured: Bool

    var body: some View {
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
