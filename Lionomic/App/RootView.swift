import SwiftUI

struct RootView: View {
    var body: some View {
        VStack(spacing: 12) {
            Text("Lionomic")
                .font(.largeTitle.weight(.semibold))
            Text("Private, local-first investing guidance")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}

#Preview {
    RootView()
        .environment(AppEnvironment())
}
