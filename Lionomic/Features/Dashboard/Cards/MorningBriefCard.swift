import SwiftUI

/// Dashboard card: shows the generated `MorningBrief` narrative and a
/// manual refresh action. First appearance (re)generates the brief via
/// `RecommendationService` + `MorningBriefService`.
struct MorningBriefCard: View {

    @Environment(AppEnvironment.self) private var env
    @State private var brief: MorningBrief?
    @State private var isGenerating = false

    var body: some View {
        DashboardCard(title: "Morning Brief", systemImage: "sun.max.fill") {
            content
        }
        .task {
            // Only auto-generate once — don't thrash on re-render.
            if brief == nil && !isGenerating {
                await regenerate()
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        if isGenerating && brief == nil {
            HStack {
                ProgressView()
                Text("Generating brief…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if let brief {
            VStack(alignment: .leading, spacing: 10) {
                Text(brief.narrativeSummary)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)

                if let note = brief.portfolioChangeNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Updated \(brief.generatedAt.formatted(date: .omitted, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Button {
                        Task { await regenerate() }
                    } label: {
                        if isGenerating {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.clockwise")
                        }
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Refresh morning brief")
                    .disabled(isGenerating)
                }
            }
        } else {
            // M11 consistency: empty state uses ContentUnavailableView like
            // the other dashboard cards. Kept the Generate action by putting
            // the button in ContentUnavailableView's `actions` slot.
            ContentUnavailableView {
                Label("No brief yet", systemImage: "sun.max")
            } description: {
                Text("Tap Generate to produce today's Morning Brief.")
            } actions: {
                Button("Generate") {
                    Task { await regenerate() }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
    }

    private func regenerate() async {
        isGenerating = true
        defer { isGenerating = false }

        // Ask lazily for notification auth the first time the user actively
        // refreshes — keeps the request out of cold-start.
        await env.morningBriefService.requestNotificationAuthorizationIfNeeded()

        let accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
        let profile = (try? env.profileRepository.fetchProfile()) ?? InvestingProfile()

        // Regenerate and persist recommendations so the brief's top-pick
        // line reflects the latest state.
        let recs = await env.recommendationService.generateAll(accounts: accounts)

        // Gather a fresh-quote snapshot for every non-NFT holding.
        var quotes: [String: QuoteResult] = [:]
        let uniqueSymbols = Set(
            accounts.flatMap { $0.holdings }
                .filter { $0.assetType.usesMarketQuote }
                .map(\.symbol)
        )
        for symbol in uniqueSymbols {
            if let cached = await env.marketDataService.cachedQuote(for: symbol), cached.isFresh {
                quotes[symbol] = cached
            }
        }

        brief = env.morningBriefService.generateBrief(
            accounts: accounts,
            profile: profile,
            quotes: quotes,
            recommendations: recs
        )
    }
}
