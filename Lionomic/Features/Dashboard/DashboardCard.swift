import SwiftUI

/// Shared visual container for dashboard cards.
/// Gives every card the same header styling, padding, corner radius, and background.
struct DashboardCard<Content: View>: View {

    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: systemImage)
                    .foregroundStyle(Color.lionomicAccent)
                Text(title)
                    .font(.headline)
                Spacer()
            }
            content
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.card, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
    }
}
