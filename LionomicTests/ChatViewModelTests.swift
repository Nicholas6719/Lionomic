import Testing
import Foundation
import SwiftData
@testable import Lionomic

/// Unit tests for `ChatViewModel`. All tests use in-memory SwiftData
/// containers and a `MockAIService` so no network calls are made.
@MainActor
struct ChatViewModelTests {

    // MARK: - Success path

    @Test func sendAppendsAssistantReplyOnSuccess() async throws {
        let (vm, mock) = try makeViewModel(response: .success("Hi there."))
        vm.inputText = "Hello?"

        await vm.send()

        #expect(vm.messages.count == 2)
        #expect(vm.messages[0].role == .user)
        #expect(vm.messages[0].content == "Hello?")
        #expect(vm.messages[1].role == .assistant)
        #expect(vm.messages[1].content == "Hi there.")
        #expect(vm.inputText == "")
        #expect(vm.errorMessage == nil)
        #expect(vm.isLoading == false)
        // System prompt is forwarded to the service on every call.
        #expect(mock.lastSystemPrompt?.isEmpty == false)
    }

    // MARK: - Error path

    @Test func sendSetsErrorMessageOnNotConfigured() async throws {
        let (vm, _) = try makeViewModel(response: .failure(.notConfigured))
        vm.inputText = "Hello?"

        await vm.send()

        // The user message is retained in the transcript — only the
        // assistant reply failed to append.
        #expect(vm.messages.count == 1)
        #expect(vm.messages[0].role == .user)
        #expect(vm.errorMessage != nil)
        #expect(vm.errorMessage?.contains("Anthropic API key") == true)
        #expect(vm.isLoading == false)
    }

    @Test func sendClearsIsLoadingOnRequestFailed() async throws {
        let (vm, _) = try makeViewModel(response: .failure(.requestFailed("boom")))
        vm.inputText = "Hello?"

        await vm.send()

        #expect(vm.isLoading == false)
        #expect(vm.errorMessage?.contains("boom") == true)
    }

    // MARK: - Clear

    @Test func clearConversationResetsState() async throws {
        let (vm, _) = try makeViewModel(response: .success("Hi."))
        vm.inputText = "Hello?"
        await vm.send()
        // Force a surfaced error too so we can verify both fields reset.
        vm.errorMessage = "Stale error"

        #expect(vm.messages.isEmpty == false)
        vm.clearConversation()

        #expect(vm.messages.isEmpty)
        #expect(vm.errorMessage == nil)
    }

    // MARK: - Empty input guard

    @Test func sendWithEmptyInputIsNoOp() async throws {
        let (vm, mock) = try makeViewModel(response: .success("Hi."))
        vm.inputText = "   \n  "

        await vm.send()

        #expect(vm.messages.isEmpty)
        #expect(vm.errorMessage == nil)
        #expect(mock.callCount == 0)
    }

    // MARK: - Helpers

    private func makeViewModel(
        response: MockAIService.Response
    ) throws -> (ChatViewModel, MockAIService) {
        let container = try ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
        let context = container.mainContext
        let profileRepo = ProfileRepository(modelContext: context)
        let portfolioRepo = PortfolioRepository(modelContext: context)
        let watchlistRepo = WatchlistRepository(modelContext: context)
        // Seeding produces the two default watchlists so the system prompt
        // builder has something to read — without it the watchlist section
        // is simply omitted, which is also fine.
        try watchlistRepo.seedDefaultsIfNeeded()

        let mock = MockAIService(response: response)
        let vm = ChatViewModel(
            aiService: mock,
            profileRepository: profileRepo,
            portfolioRepository: portfolioRepo,
            watchlistRepository: watchlistRepo
        )
        return (vm, mock)
    }
}

// MARK: - Mock

/// In-test `AIService` that returns a canned reply or error. Records the
/// last call so tests can assert on what was forwarded to the service.
final class MockAIService: AIService, @unchecked Sendable {

    enum Response {
        case success(String)
        case failure(AIServiceError)
    }

    nonisolated(unsafe) var response: Response
    nonisolated(unsafe) private(set) var callCount: Int = 0
    nonisolated(unsafe) private(set) var lastSystemPrompt: String?
    nonisolated(unsafe) private(set) var lastMessages: [AIMessage] = []

    init(response: Response) {
        self.response = response
    }

    nonisolated var isAvailable: Bool { true }

    nonisolated func complete(system: String, messages: [AIMessage]) async throws -> String {
        callCount += 1
        lastSystemPrompt = system
        lastMessages = messages
        switch response {
        case .success(let text):
            return text
        case .failure(let error):
            throw error
        }
    }

    nonisolated func complete(prompt: String) async throws -> String {
        try await complete(
            system: "",
            messages: [AIMessage(role: .user, content: prompt)]
        )
    }
}
