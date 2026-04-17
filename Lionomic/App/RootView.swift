import SwiftUI
import SwiftData

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
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    RootView()
        .environment(AppEnvironment(modelContainer: container))
        .modelContainer(container)
}
