import SwiftUI

/// Compact pill showing a recommendation category. Shared across the
/// dashboard card and the full list so the color/shape stays consistent.
struct RecommendationCategoryBadge: View {
    let category: RecommendationCategory

    var body: some View {
        Text(category.displayName)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(category.badgeColor.opacity(0.18), in: Capsule())
            .foregroundStyle(category.badgeColor)
    }
}
