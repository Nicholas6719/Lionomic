import Foundation
import UserNotifications

/// Pure decision functions that UI surfaces (PriceAlertSheet,
/// EditPreferencesView) call to decide whether to prompt the user for
/// notification authorization, or whether to render an inline
/// "notifications disabled" note. Extracted into a dedicated type so the
/// conditional logic is testable without mocking `UNUserNotificationCenter`.
///
/// The actual I/O (calling `requestAuthorization()`, reading
/// `authorizationStatus()`) lives in `NotificationService`; this type is
/// only the branching rules.
enum NotificationAuthGate {

    /// True when the UI should invoke `NotificationService.requestAuthorization()`
    /// on a user-initiated "enable alerts" moment. The one and only green
    /// light is `.notDetermined` — every other state (authorized, denied,
    /// provisional, ephemeral) either already answered the question or
    /// would be a re-prompt the system ignores.
    static func shouldPrompt(currentStatus: UNAuthorizationStatus) -> Bool {
        currentStatus == .notDetermined
    }

    /// True when the UI should surface the inline "notifications disabled"
    /// note. Only shown for `.denied` — `.notDetermined` means the user
    /// hasn't been asked yet, so there's nothing disabled to warn about.
    static func shouldShowDeniedNote(currentStatus: UNAuthorizationStatus) -> Bool {
        currentStatus == .denied
    }
}
