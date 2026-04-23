import Foundation
import UserNotifications
import os

/// Single path to `UNUserNotificationCenter` for the entire app. Every
/// notification goes through this service — no other type imports
/// `UserNotifications` directly.
///
/// Authorization is lazy and idempotent: `requestAuthorization()` only
/// prompts when the system has never decided. Calls to `send(...)` silently
/// no-op when the user has declined — callers don't need to check.
@MainActor
final class NotificationService {

    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// Requests `[.alert, .sound]` the first time only. Subsequent calls
    /// with status `.denied` / `.authorized` / `.provisional` / `.ephemeral`
    /// return without prompting.
    ///
    /// MBackground: widened to return `Bool` so UI surfaces that prompt at
    /// a user-initiated moment (PriceAlertSheet Save, preference toggles)
    /// can surface a "notifications disabled" inline note when the user
    /// has previously denied or just denied the prompt. `true` means the
    /// app is currently authorized (including provisional/ephemeral).
    /// Marked `@discardableResult` for call sites that only want the
    /// prompt side-effect.
    @discardableResult
    func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined:
            do {
                return try await center.requestAuthorization(options: [.alert, .sound])
            } catch {
                Log.app.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
                return false
            }
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        @unknown default:
            return false
        }
    }

    /// Read-only peek at the current authorization status. Lets UI gate
    /// display of "notifications disabled" notes without triggering a
    /// prompt. Returns `UNAuthorizationStatus` directly — callers usually
    /// only care about `.denied` vs everything else.
    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Posts an immediate local notification. `identifier` is used to
    /// replace any pending request with the same identifier — callers
    /// should pick a stable identifier for notifications that logically
    /// supersede each other (e.g. `"rec.change.AAPL"`).
    ///
    /// No-op when the user has not authorized. Never re-prompts.
    func send(title: String, body: String, identifier: String) async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .authorized
           || settings.authorizationStatus == .provisional
           || settings.authorizationStatus == .ephemeral else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil  // immediate
        )
        do {
            try await center.add(request)
        } catch {
            Log.app.error("Notification post failed (\(identifier, privacy: .public)): \(String(describing: error), privacy: .public)")
        }
    }

    /// Removes both pending and already-delivered notifications sharing
    /// `identifier`. Call when an alert becomes obsolete before the user
    /// has interacted with it.
    func cancel(identifier: String) {
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        center.removeDeliveredNotifications(withIdentifiers: [identifier])
    }

    /// Wipes every pending and delivered notification. Wire this into
    /// `AppEnvironment.resetAllData()` so a data reset doesn't leave
    /// stale notifications hanging around in Notification Center.
    func cancelAll() {
        center.removeAllPendingNotificationRequests()
        center.removeAllDeliveredNotifications()
    }
}
