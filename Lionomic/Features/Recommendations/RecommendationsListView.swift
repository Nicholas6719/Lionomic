import SwiftUI
import SwiftData

/// The Insights tab. Shows every persisted recommendation grouped by
/// account, with a toolbar action to regenerate.
struct RecommendationsListView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [Account] = []
    @State private var recommendations: [Recommendation] = []
    @State private var isGenerating = false
    @State private var hasLoaded = false

    var body: some View {
        content
            .navigationTitle("Insights")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    Task { await regenerate() }
                } label: {
                    if isGenerating {
                        ProgressView()
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .accessibilityLabel("Regenerate recommendations")
                .disabled(isGenerating)
            }
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            // M11 consistency: ProgressView during initial load keeps the
            // empty state from flashing before the fetch completes.
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else if recommendations.isEmpty {
            ContentUnavailableView {
                Label("No recommendations yet", systemImage: "lightbulb")
            } description: {
                Text("Tap the refresh button to analyze your holdings and generate recommendations.")
            }
        } else {
            List {
                ForEach(groupedByAccount(), id: \.accountID) { group in
                    Section(group.accountName) {
                        ForEach(group.items) { rec in
                            RecommendationRow(recommendation: rec)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    // MARK: - Data

    private struct AccountGroup: Identifiable {
        let accountID: UUID
        let accountName: String
        let items: [Recommendation]
        var id: UUID { accountID }
    }

    private func groupedByAccount() -> [AccountGroup] {
        let nameByID: [UUID: String] = Dictionary(
            uniqueKeysWithValues: accounts.map { ($0.id, $0.displayName) }
        )
        let grouped = Dictionary(grouping: recommendations) { $0.accountID }
        return grouped.map { key, value in
            AccountGroup(
                accountID: key,
                accountName: nameByID[key] ?? "Unknown account",
                items: value.sorted { $0.confidence > $1.confidence }
            )
        }
        .sorted { $0.accountName < $1.accountName }
    }

    private func reload() async {
        defer { hasLoaded = true }
        accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
        recommendations = (try? env.recommendationService.fetchAll()) ?? []
    }

    private func regenerate() async {
        isGenerating = true
        defer { isGenerating = false }
        let accounts = (try? env.portfolioRepository.fetchAccounts()) ?? []
        _ = await env.recommendationService.generateAll(accounts: accounts)
        await reload()
    }
}

private struct RecommendationRow: View {
    let recommendation: Recommendation

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Text(recommendation.symbol)
                    .font(.subheadline.weight(.semibold))
                RecommendationCategoryBadge(category: recommendation.categoryEnum)
                Spacer()
                Text(PercentFormatter.string(from: Decimal(recommendation.confidence), fractionDigits: 0))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            ConfidenceBar(value: recommendation.confidence)

            Text(recommendation.reasoning)
                .font(.caption)
                .foregroundStyle(.secondary)

            if !recommendation.cautionNote.isEmpty {
                Label(recommendation.cautionNote, systemImage: "exclamationmark.triangle")
                    .font(.caption2)
                    .foregroundStyle(.orange)
            }

            // M11: surface the M8 structured supporting outputs. Collapsed
            // by default — most users only want the winning rule's story.
            if !recommendation.supportingOutputs.isEmpty {
                DisclosureGroup("Also considered") {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(recommendation.supportingOutputs, id: \.self) { output in
                            HStack(alignment: .top, spacing: 8) {
                                RecommendationCategoryBadge(category: output.category)
                                Text(output.reasoning)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 0)
                            }
                        }
                    }
                    .padding(.top, 4)
                }
                .font(.caption)
            }
        }
        .padding(.vertical, 4)
    }
}

private struct ConfidenceBar: View {
    let value: Double

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.15))
                Capsule()
                    .fill(.tint)
                    .frame(width: proxy.size.width * CGFloat(max(0, min(1, value))))
            }
        }
        .frame(height: 4)
    }
}
