import SwiftUI

/// Dashboard card: top-3 recommendations by confidence.
/// If none exist yet, shows a brief explanatory note; the full Insights tab
/// handles regeneration.
struct RecommendationsCard: View {

    @Environment(AppEnvironment.self) private var env
    @State private var top: [Recommendation] = []
    @State private var hasLoaded = false

    var body: some View {
        DashboardCard(title: "Recommendations", systemImage: "lightbulb.fill") {
            content
        }
        .task { await reload() }
    }

    @ViewBuilder
    private var content: some View {
        if !hasLoaded {
            HStack {
                Spacer()
                ProgressView()
                Spacer()
            }
            .padding(.vertical, 16)
        } else if top.isEmpty {
            ContentUnavailableView {
                Label("No recommendations yet", systemImage: "lightbulb")
            } description: {
                Text("Open the Insights tab to generate fresh recommendations from your holdings.")
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        } else {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                ForEach(top) { rec in
                    TopRow(recommendation: rec)
                    if rec.id != top.last?.id { Divider() }
                }
                NavigationLink {
                    RecommendationsListView()
                } label: {
                    Text("See all")
                        .font(.footnote.weight(.medium))
                }
                .padding(.top, 4)
            }
        }
    }

    private func reload() async {
        defer { hasLoaded = true }
        let all = (try? env.recommendationService.fetchAll()) ?? []
        top = Array(all.prefix(3))
    }
}

private struct TopRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(recommendation.symbol)
                        .font(.body.weight(.bold))
                    RecommendationCategoryBadge(category: recommendation.categoryEnum)
                }
                Text(recommendation.reasoning)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                ConfidencePipsView(confidence: recommendation.confidence)
            }
            Spacer(minLength: 0)
        }
    }
}
