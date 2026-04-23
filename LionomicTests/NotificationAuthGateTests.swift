import Testing
import Foundation
import UserNotifications
@testable import Lionomic

/// Tests the pure decision functions that UI surfaces use to decide
/// whether to prompt for notification auth and whether to show the
/// "notifications disabled" inline note. Mocking the real
/// `UNUserNotificationCenter.authorizationStatus` is impractical without
/// heavyweight test infrastructure (UNNotificationSettings has no
/// public initializer), so we test the branching logic directly against
/// every `UNAuthorizationStatus` value.
struct NotificationAuthGateTests {

    @Test("shouldPrompt returns true only when status is .notDetermined")
    func promptTriggeredOnlyForNotDetermined() {
        #expect(NotificationAuthGate.shouldPrompt(currentStatus: .notDetermined) == true)

        // Every other status must NOT re-prompt — the system would ignore
        // the request anyway and the UX would be a dead-end spinner.
        #expect(NotificationAuthGate.shouldPrompt(currentStatus: .denied) == false)
        #expect(NotificationAuthGate.shouldPrompt(currentStatus: .authorized) == false)
        #expect(NotificationAuthGate.shouldPrompt(currentStatus: .provisional) == false)
    }

    @Test("shouldShowDeniedNote returns true only when status is .denied")
    func deniedNoteOnlyForDenied() {
        #expect(NotificationAuthGate.shouldShowDeniedNote(currentStatus: .denied) == true)

        // We only warn when the user actively said no — the
        // `.notDetermined` case still has a prompt to run, and authorized
        // / provisional mean things are working.
        #expect(NotificationAuthGate.shouldShowDeniedNote(currentStatus: .notDetermined) == false)
        #expect(NotificationAuthGate.shouldShowDeniedNote(currentStatus: .authorized) == false)
        #expect(NotificationAuthGate.shouldShowDeniedNote(currentStatus: .provisional) == false)
    }
}
