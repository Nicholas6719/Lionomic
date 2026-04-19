import SwiftUI

/// Placeholder content for the Insights tab. Replaced in M7 when the
/// recommendation engine lands.
struct InsightsPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Insights", systemImage: "lightbulb")
        } description: {
            Text("Recommendations and analysis coming soon.")
        }
        .navigationTitle("Insights")
    }
}

#Preview {
    NavigationStack { InsightsPlaceholderView() }
}
