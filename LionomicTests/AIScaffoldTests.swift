import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Wire proof for the M10 AI scaffold. None of these tests exercise a
/// real network call — the point is to verify the shapes and defaults.
@MainActor
struct AIScaffoldTests {

    @Test func noopServiceIsUnavailable() async throws {
        #expect(NoopAIService().isAvailable == false)
    }

    @Test func noopServiceThrowsNotConfigured() async throws {
        let service = NoopAIService()
        do {
            _ = try await service.complete(prompt: "anything")
            Issue.record("Expected NoopAIService.complete to throw")
        } catch let error as AIServiceError {
            #expect(error == .notConfigured)
        }
    }

    @Test func anthropicStubIsAvailableWhenKeyNonEmpty() async throws {
        #expect(AnthropicAIService(apiKey: "test").isAvailable == true)
    }

    @Test func anthropicStubIsUnavailableWhenKeyEmpty() async throws {
        #expect(AnthropicAIService(apiKey: "").isAvailable == false)
    }

    @Test func anthropicThrowsNotConfiguredWhenKeyEmpty() async throws {
        // MChat: the empty-key path still short-circuits with
        // `.notConfigured` before any HTTP attempt. Non-empty keys now go
        // to the network, so we cannot exercise that path deterministically
        // in a unit test.
        let service = AnthropicAIService(apiKey: "")
        do {
            _ = try await service.complete(prompt: "anything")
            Issue.record("Expected AnthropicAIService.complete to throw when no key is configured")
        } catch let error as AIServiceError {
            #expect(error == .notConfigured)
        }
    }

    @Test func appEnvironmentExposesAIService() async throws {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let env = AppEnvironment(modelContainer: container)
        // MChat: AppEnvironment now wires an AnthropicAIService (not
        // NoopAIService). `isAvailable` depends on the runtime Keychain
        // state, so we only assert the type of the wired service here.
        #expect(env.aiService is AnthropicAIService)
    }
}
