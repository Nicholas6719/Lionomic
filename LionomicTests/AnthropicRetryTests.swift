import Testing
import Foundation
@testable import Lionomic

/// MContext: covers `AnthropicAIService.withRetry` classification and
/// loop behavior. Tests inject a zero-delay `sleep` and a deterministic
/// `jitter` so they run instantly and don't depend on wall-clock time.
struct AnthropicRetryTests {

    // MARK: - Classification (pure)

    @Test("isRetryable returns true for 429 and every 5xx status")
    func retryableClassification() {
        #expect(AnthropicAIService.isRetryable(statusCode: 429) == true)
        #expect(AnthropicAIService.isRetryable(statusCode: 500) == true)
        #expect(AnthropicAIService.isRetryable(statusCode: 502) == true)
        #expect(AnthropicAIService.isRetryable(statusCode: 503) == true)
        #expect(AnthropicAIService.isRetryable(statusCode: 599) == true)
    }

    @Test("isRetryable returns false for 2xx, 4xx (except 429), and 3xx")
    func nonRetryableClassification() {
        #expect(AnthropicAIService.isRetryable(statusCode: 200) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 301) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 400) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 401) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 403) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 404) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 422) == false)
        // Boundary conditions: 428 and 430 are not retryable even though
        // 429 is — the check is exact, not a range.
        #expect(AnthropicAIService.isRetryable(statusCode: 428) == false)
        #expect(AnthropicAIService.isRetryable(statusCode: 430) == false)
        // Nothing above 5xx retries either.
        #expect(AnthropicAIService.isRetryable(statusCode: 600) == false)
    }

    // MARK: - Backoff math (pure)

    @Test("backoffDelay produces the documented exponential schedule with jitter")
    func backoffDelaySchedule() {
        // With base 1.0, multiplier 2.0, jitter 0:
        //   attempt 2 (first retry) → 1 * 2^0 = 1.0
        //   attempt 3 (second retry) → 1 * 2^1 = 2.0
        //   attempt 4 (third retry)  → 1 * 2^2 = 4.0
        let d2 = AnthropicAIService.backoffDelay(beforeAttempt: 2, baseDelay: 1.0, multiplier: 2.0, jitter: 0)
        let d3 = AnthropicAIService.backoffDelay(beforeAttempt: 3, baseDelay: 1.0, multiplier: 2.0, jitter: 0)
        let d4 = AnthropicAIService.backoffDelay(beforeAttempt: 4, baseDelay: 1.0, multiplier: 2.0, jitter: 0)
        #expect(d2 == 1.0)
        #expect(d3 == 2.0)
        #expect(d4 == 4.0)

        // Jitter is simply added on top.
        let jittered = AnthropicAIService.backoffDelay(beforeAttempt: 3, baseDelay: 1.0, multiplier: 2.0, jitter: 0.3)
        #expect(jittered == 2.3)
    }

    // MARK: - Loop: retryable exhaustion

    @Test("Retryable failures retry up to maxAttempts, then throw the last error")
    func retryableExhaustsAfterMaxAttempts() async {
        var attempts = 0
        var sleeps: [TimeInterval] = []
        // Explicit return type on the operation closure pins the generic
        // parameter `T` — without it Swift can't infer String from a
        // closure body that only ever produces `.retryable(...)`.
        let op: @Sendable () async -> AnthropicAIService.RetryAttempt<String> = {
            attempts += 1
            return .retryable(AIServiceError.requestFailed("status 503: backend down"))
        }
        do {
            _ = try await AnthropicAIService.withRetry(
                maxAttempts: 3,
                baseDelay: 1.0,
                multiplier: 2.0,
                jitter: { 0 },
                sleep: { sleeps.append($0) },
                operation: op
            )
            Issue.record("Expected withRetry to throw after exhausting attempts")
        } catch {
            // Expected — the loop exhausted without success.
            let e = error as? AIServiceError
            #expect(e == AIServiceError.requestFailed("status 503: backend down"))
        }
        // 1 original + 2 retries = 3 attempts.
        #expect(attempts == 3)
        // Two sleeps between the three attempts: 1.0 and 2.0.
        #expect(sleeps == [1.0, 2.0])
    }

    // MARK: - Loop: fatal classification

    @Test("Fatal failures return on the first attempt and do not sleep")
    func fatalFailsImmediately() async {
        var attempts = 0
        var sleeps: [TimeInterval] = []
        let op: @Sendable () async -> AnthropicAIService.RetryAttempt<String> = {
            attempts += 1
            return .fatal(AIServiceError.requestFailed("status 401: bad key"))
        }
        do {
            _ = try await AnthropicAIService.withRetry(
                maxAttempts: 3,
                baseDelay: 1.0,
                multiplier: 2.0,
                jitter: { 0 },
                sleep: { sleeps.append($0) },
                operation: op
            )
            Issue.record("Expected withRetry to throw on the fatal result")
        } catch {
            let e = error as? AIServiceError
            #expect(e == AIServiceError.requestFailed("status 401: bad key"))
        }
        #expect(attempts == 1)
        #expect(sleeps.isEmpty)
    }

    // MARK: - Loop: success on retry

    @Test("Success on the second attempt returns the value without a third attempt")
    func secondAttemptSuccessShortCircuits() async throws {
        var attempts = 0
        var sleeps: [TimeInterval] = []
        let op: @Sendable () async -> AnthropicAIService.RetryAttempt<String> = {
            attempts += 1
            if attempts == 1 {
                return .retryable(AIServiceError.requestFailed("status 429: slow down"))
            }
            return .success("recovered")
        }

        let result = try await AnthropicAIService.withRetry(
            maxAttempts: 3,
            baseDelay: 1.0,
            multiplier: 2.0,
            jitter: { 0 },
            sleep: { sleeps.append($0) },
            operation: op
        )

        #expect(result == "recovered")
        #expect(attempts == 2)
        // Slept once (after the retryable first attempt, before the
        // successful second).
        #expect(sleeps == [1.0])
    }

    // MARK: - Loop: success on first

    @Test("Success on the first attempt returns immediately with no sleeps")
    func firstAttemptSuccessIsFast() async throws {
        var attempts = 0
        var sleeps: [TimeInterval] = []
        let op: @Sendable () async -> AnthropicAIService.RetryAttempt<String> = {
            attempts += 1
            return .success("first-try")
        }
        let result = try await AnthropicAIService.withRetry(
            maxAttempts: 3,
            baseDelay: 1.0,
            multiplier: 2.0,
            jitter: { 0 },
            sleep: { sleeps.append($0) },
            operation: op
        )
        #expect(result == "first-try")
        #expect(attempts == 1)
        #expect(sleeps.isEmpty)
    }

    // MARK: - Loop: transition from retryable to fatal

    @Test("A fatal result mid-loop stops the loop even if the prior attempt was retryable")
    func fatalAfterRetryableStopsLoop() async {
        var attempts = 0
        let op: @Sendable () async -> AnthropicAIService.RetryAttempt<String> = {
            attempts += 1
            if attempts == 1 {
                return .retryable(AIServiceError.requestFailed("status 503"))
            }
            return .fatal(AIServiceError.requestFailed("status 401"))
        }
        do {
            _ = try await AnthropicAIService.withRetry(
                maxAttempts: 3,
                baseDelay: 1.0,
                multiplier: 2.0,
                jitter: { 0 },
                sleep: { _ in },
                operation: op
            )
            Issue.record("Expected withRetry to throw on the fatal second attempt")
        } catch {
            let e = error as? AIServiceError
            #expect(e == AIServiceError.requestFailed("status 401"))
        }
        #expect(attempts == 2)
    }
}
