import SwiftUI

/// Placeholder. Full recommendation engine arrives in M7.
struct RecommendationsCard: View {
    var body: some View {
        DashboardCard(title: "Recommendations", systemImage: "lightbulb.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Available in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Opinionated, evidence-backed recommendations tailored to your profile and accounts.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
