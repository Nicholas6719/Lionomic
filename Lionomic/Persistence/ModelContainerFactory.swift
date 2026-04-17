import Foundation
import SwiftData

enum ModelContainerFactory {
    static func makeSharedContainer(
        for models: [any PersistentModel.Type],
        isStoredInMemoryOnly: Bool = false
    ) throws -> ModelContainer {
        let schema = Schema(models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: isStoredInMemoryOnly
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }
}
