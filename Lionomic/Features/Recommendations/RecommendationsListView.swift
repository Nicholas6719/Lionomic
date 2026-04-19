import SwiftUI
import SwiftData

/// The Insights tab. Shows every persisted recommendation grouped by
/// account, with a toolbar action to regenerate.
struct RecommendationsListView: View {

    @Environment(AppEnvironment.self) private var env
    @State private var accounts: [Account] = []
    @State private var recommendations: [Recommendation] = []
    @State private var isGenerating = false

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
        if recommendations.isEmpty {
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
