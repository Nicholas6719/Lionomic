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
    func requestAuthorization() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            Log.app.error("Notification auth request failed: \(String(describing: error), privacy: .public)")
        }
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
