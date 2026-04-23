import SwiftUI
import UserNotifications

/// Shared sheet for editing above/below price alert thresholds.
///
/// Used by both the holding list (swipe → "Alerts") and the watchlist
/// (swipe → "Alerts"). Lives in `Features/Portfolio` because both sides
/// share the same Decimal-parsing pattern and the same Save/Cancel flow.
struct PriceAlertSheet: View {

    let symbol: String
    let alertsFeatureEnabled: Bool
    @State private var aboveText: String
    @State private var belowText: String
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined
    @State private var isSaving = false
    private let onSave: (_ above: Decimal?, _ below: Decimal?) -> Void

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    init(
        symbol: String,
        initialAbove: Decimal?,
        initialBelow: Decimal?,
        alertsFeatureEnabled: Bool,
        onSave: @escaping (_ above: Decimal?, _ below: Decimal?) -> Void
    ) {
        self.symbol = symbol
        self.alertsFeatureEnabled = alertsFeatureEnabled
        self.onSave = onSave
        _aboveText = State(initialValue: initialAbove.map { Self.format($0) } ?? "")
        _belowText = State(initialValue: initialBelow.map { Self.format($0) } ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if !alertsFeatureEnabled {
                    Section {
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(Color(.systemOrange))
                            Text("Price alerts are turned off in Settings → App Preferences. Thresholds you save here will not fire notifications until you re-enable them.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if NotificationAuthGate.shouldShowDeniedNote(currentStatus: notificationStatus) {
                    Section {
                        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "bell.slash.fill")
                                .foregroundStyle(Color(.systemOrange))
                            Text("Notifications are disabled for Lionomic. Thresholds will be stored, but no alert will fire until you enable notifications in iOS Settings.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    TextField("Alert above", text: $aboveText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Notify when price rises above")
                } footer: {
                    Text("Leave blank to clear. Value is a USD price — e.g. 185.50.")
                }

                Section {
                    TextField("Alert below", text: $belowText)
                        .keyboardType(.decimalPad)
                } header: {
                    Text("Notify when price falls below")
                } footer: {
                    Text("Leave blank to clear.")
                }
            }
            .navigationTitle("Alerts for \(symbol)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task { await save() }
                    }
                    .disabled(isSaving)
                }
            }
            .task {
                // Peek only — we don't prompt on appear. The prompt fires
                // the first time the user taps Save (i.e. at a clear,
                // user-initiated moment).
                notificationStatus = await env.notificationService.authorizationStatus()
            }
        }
    }

    // MARK: - Save

    /// Saving is unconditional — thresholds persist even when the user
    /// denies notifications. That matches the spec: the threshold is
    /// still valid state; only delivery is affected. When status is
    /// `.notDetermined`, we request once at this moment; the user's
    /// answer updates `notificationStatus` so the inline note surfaces
    /// on a subsequent open if they tapped Don't Allow.
    private func save() async {
        isSaving = true
        defer { isSaving = false }

        if NotificationAuthGate.shouldPrompt(currentStatus: notificationStatus) {
            _ = await env.notificationService.requestAuthorization()
            notificationStatus = await env.notificationService.authorizationStatus()
        }

        onSave(parse(aboveText), parse(belowText))
        dismiss()
    }

    private func parse(_ text: String) -> Decimal? {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }
        return Decimal(string: trimmed)
    }

    private static func format(_ value: Decimal) -> String {
        NSDecimalNumber(decimal: value).stringValue
    }
}
