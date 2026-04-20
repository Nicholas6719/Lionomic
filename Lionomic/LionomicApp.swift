import SwiftUI
import SwiftData

@main
struct LionomicApp: App {
    @State private var appEnvironment: AppEnvironment

    init() {
        do {
            let container = try ModelContainerFactory.makeSharedContainer()
            let env = AppEnvironment(modelContainer: container)
            _appEnvironment = State(initialValue: env)

            // BGTask handlers **must** be registered before
            // `applicationDidFinishLaunching` returns. SwiftUI's `App.init`
            // runs before scene setup, which is early enough.
            MorningBriefBackgroundTask.register(env: env)
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
