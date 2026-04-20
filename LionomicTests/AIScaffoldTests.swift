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

    @Test func anthropicStubThrowsNotConfigured() async throws {
        let service = AnthropicAIService(apiKey: "test")
        do {
            _ = try await service.complete(prompt: "anything")
            Issue.record("Expected AnthropicAIService.complete to throw in V1")
        } catch let error as AIServiceError {
            #expect(error == .notConfigured)
        }
    }

    @Test func appEnvironmentExposesAIService() async throws {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let env = AppEnvironment(modelContainer: container)
        // In V1 AppEnvironment always wires NoopAIService — isAvailable must be false.
        #expect(env.aiService.isAvailable == false)
    }
}
