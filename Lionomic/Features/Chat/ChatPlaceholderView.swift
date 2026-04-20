import SwiftUI

/// Placeholder destination for the Chat tab. Only reachable when
/// `AppPreferences.chatEnabled == true` — in V1 that flag is never set,
/// so this view is effectively unreachable in production. Lives here so
/// the tab has a destination the moment the flag flips.
struct ChatPlaceholderView: View {
    var body: some View {
        ContentUnavailableView {
            Label("Chat", systemImage: "message")
        } description: {
            Text("AI-powered chat is coming in a future update.")
        }
        .navigationTitle("Chat")
    }
}

#Preview {
    NavigationStack { ChatPlaceholderView() }
}
