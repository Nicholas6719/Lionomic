import SwiftUI
import SwiftData

@main
struct LionomicApp: App {
    @State private var appEnvironment: AppEnvironment

    init() {
        do {
            let container = try ModelContainerFactory.makeSharedContainer()
            _appEnvironment = State(initialValue: AppEnvironment(modelContainer: container))
        } catch {
            Log.app.fault("ModelContainer init failed: \(String(describing: error), privacy: .public)")
            fatalError("Could not create ModelContainer: \(error)")
        }
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appEnvironment)
                .modelContainer(appEnvironment.modelContainer)
                .task {
                    appEnvironment.seedOnFirstLaunch()
                }
        }
    }
}
