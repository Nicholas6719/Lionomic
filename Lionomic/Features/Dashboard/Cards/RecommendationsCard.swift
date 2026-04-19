import SwiftUI

/// Dashboard card: top-3 recommendations by confidence.
/// If none exist yet, shows a brief explanatory note; the full Insights tab
/// handles regeneration.
struct RecommendationsCard: View {

    @Environment(AppEnvironment.self) private var env
    @State private var top: [Recommendation] = []

    var body: some View {
        DashboardCard(title: "Recommendations", systemImage: "lightbulb.fill") {
            if top.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("No recommendations yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Text("Open the Insights tab to generate fresh recommendations from your holdings.")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            } else {
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(top) { rec in
                        TopRow(recommendation: rec)
                        if rec.id != top.last?.id { Divider() }
                    }
                    NavigationLink {
                        RecommendationsListView()
                    } label: {
                        Text("See all")
                            .font(.caption.weight(.medium))
                    }
                    .padding(.top, 4)
                }
            }
        }
        .task { await reload() }
    }

    private func reload() async {
        let all = (try? env.recommendationService.fetchAll()) ?? []
        top = Array(all.prefix(3))
    }
}

private struct TopRow: View {
    let recommendation: Recommendation

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(recommendation.symbol)
                        .font(.subheadline.weight(.semibold))
                    RecommendationCategoryBadge(category: recommendation.categoryEnum)
                }
                Text(recommendation.reasoning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
        }
    }
}
