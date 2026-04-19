import SwiftUI

/// Placeholder. Full morning brief lands in M8.
struct MorningBriefCard: View {
    var body: some View {
        DashboardCard(title: "Morning Brief", systemImage: "sun.max.fill") {
            VStack(alignment: .leading, spacing: 6) {
                Text("Available in a future update.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("A personalized morning summary of overnight moves, notable changes, and suggested actions.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
