import Testing
import Foundation
@testable import Lionomic

struct RateLimiterTests {

    /// Uses a 100-ms gap so tests stay fast.
    private let testProvider = "TEST"
    private let gap: TimeInterval = 0.1

    private func makeLimiter() -> RateLimiter {
        RateLimiter(gaps: [testProvider: gap])
    }

    @Test("A fresh limiter allows a call immediately")
    func freshLimiterAllowsFirstCall() async {
        let limiter = makeLimiter()
        let allowed = await limiter.acquire(provider: testProvider)
        #expect(allowed == true)
    }

    @Test("A second call within the gap is denied")
    func secondCallWithinGapIsDenied() async {
        let limiter = makeLimiter()
        _ = await limiter.acquire(provider: testProvider)
        let second = await limiter.acquire(provider: testProvider)
        #expect(second == false)
    }

    @Test("After the gap elapses, a call is allowed again")
    func callAllowedAfterGap() async throws {
        let limiter = makeLimiter()
        _ = await limiter.acquire(provider: testProvider)
        // Wait slightly longer than the configured gap.
        try await Task.sleep(nanoseconds: UInt64((gap + 0.05) * 1_000_000_000))
        let third = await limiter.acquire(provider: testProvider)
        #expect(third == true)
    }

    @Test("Denied call does not reset the clock")
    func deniedCallDoesNotResetClock() async throws {
        let limiter = makeLimiter()
        _ = await limiter.acquire(provider: testProvider)      // allowed, stamps
        _ = await limiter.acquire(provider: testProvider)      // denied, should NOT re-stamp
        try await Task.sleep(nanoseconds: UInt64((gap + 0.05) * 1_000_000_000))
        let third = await limiter.acquire(provider: testProvider)
        #expect(third == true)
    }
}
