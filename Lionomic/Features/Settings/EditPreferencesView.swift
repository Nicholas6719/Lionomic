import SwiftUI
import UserNotifications

/// Settings → App Preferences editor.
/// Covers every `AppPreferences` field except `biometricsEnabled` (owned by
/// `BiometricsSettingsView`) and `firstLaunchComplete` (onboarding gate).
/// Follows draft/review/confirm.
struct EditPreferencesView: View {

    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var draft = DraftPreferences()
    @State private var showingReview = false
    @State private var errorMessage: String?
    @State private var loaded = false
    @State private var notificationStatus: UNAuthorizationStatus = .notDetermined

    // Allowed refresh cadences — matches the prompt's segmented options.
    private let cadenceOptions: [Int] = [5, 15, 30, 60]

    var body: some View {
        Form {
            Section {
                HStack {
                    Text("Hour")
                    Spacer()
                    Picker("Hour", selection: $draft.morningBriefHour) {
                        ForEach(0..<24, id: \.self) {
                            Text(String(format: "%02d", $0)).tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                    Text(":")
                    Picker("Minute", selection: $draft.morningBriefMinute) {
                        ForEach([0, 15, 30, 45], id: \.self) {
                            Text(String(format: "%02d", $0)).tag($0)
                        }
                    }
                    .pickerStyle(.wheel)
                    .frame(width: 80, height: 100)
                }
            } header: {
                Text("Morning Brief")
            } footer: {
                Text("Lionomic delivers a Morning Brief notification around this time each day when the app refreshes in the background.")
            }

            Section {
                Picker("Refresh every", selection: $draft.quoteRefreshCadenceMinutes) {
                    ForEach(cadenceOptions, id: \.self) { minutes in
                        Text("\(minutes) min").tag(minutes)
                    }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Quote Refresh")
            } footer: {
                Text("Lionomic stays on free-plan limits by capping automatic refreshes.")
            }

            Section {
                Toggle("Price Movement Alerts",          isOn: $draft.priceAlertsEnabled)
                Toggle("Watchlist Opportunity Alerts",   isOn: $draft.watchlistAlertsEnabled)
                Toggle("Holding Risk Alerts",            isOn: $draft.holdingRiskAlertsEnabled)
                Toggle("Recommendation Change Alerts",   isOn: $draft.recommendationChangeAlertsEnabled)
            } header: {
                Text("Notifications")
            } footer: {
                if notificationStatus == .denied
                    && (draft.priceAlertsEnabled || draft.watchlistAlertsEnabled
                        || draft.holdingRiskAlertsEnabled
                        || draft.recommendationChangeAlertsEnabled) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Notifications are disabled for Lionomic in iOS Settings. Alerts will be recorded but no banner will appear until you re-enable them.")
                        Text("Preferences are still saved locally — nothing is sent to a server. Set per-symbol price thresholds on holdings and watchlist items.")
                    }
                } else {
                    Text("Notifications are scheduled locally — nothing is sent to a server. Set per-symbol price thresholds on holdings and watchlist items.")
                }
            }
        }
        .navigationTitle("App Preferences")
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Review") { showingReview = true }
            }
        }
        .task {
            if !loaded {
                if let prefs = env.preferencesRepository.currentPreferences {
                    draft = DraftPreferences(editing: prefs)
                }
                loaded = true
            }
            notificationStatus = await env.notificationService.authorizationStatus()
        }
        // MBackground: when the user turns ON either of the newly-wired
        // alert toggles, prompt for notification auth (once — the service
        // only asks when status is .notDetermined) and refresh our local
        // status so the inline denied-note updates. Turning a toggle OFF
        // does nothing.
        .onChange(of: draft.priceAlertsEnabled) { oldValue, newValue in
            guard !oldValue && newValue else { return }
            Task { await requestAuthIfNeeded() }
        }
        .onChange(of: draft.watchlistAlertsEnabled) { oldValue, newValue in
            guard !oldValue && newValue else { return }
            Task { await requestAuthIfNeeded() }
        }
        .sheet(isPresented: $showingReview) {
            EditPreferencesReviewSheet(draft: draft) {
                do {
                    try env.preferencesRepository.commit(draft: draft)
                    showingReview = false
                    dismiss()
                } catch {
                    errorMessage = error.localizedDescription
                    showingReview = false
                }
            }
        }
        .alert("Could not save", isPresented: .init(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            if let msg = errorMessage { Text(msg) }
        }
    }

    /// Request notification auth once, but only when the system status
    /// is actually `.notDetermined` (decided by `NotificationAuthGate`).
    /// Always refresh our local `notificationStatus` afterwards so the
    /// inline denied-note can appear if the user tapped Don't Allow.
    private func requestAuthIfNeeded() async {
        let status = await env.notificationService.authorizationStatus()
        if NotificationAuthGate.shouldPrompt(currentStatus: status) {
            _ = await env.notificationService.requestAuthorization()
        }
        notificationStatus = await env.notificationService.authorizationStatus()
    }
}

private struct EditPreferencesReviewSheet: View {
    let draft: DraftPreferences
    let onConfirm: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section("Review") {
                    LabeledContent("Morning Brief") {
                        Text(String(format: "%02d:%02d", draft.morningBriefHour, draft.morningBriefMinute))
                    }
                    LabeledContent("Refresh every",        value: "\(draft.quoteRefreshCadenceMinutes) min")
                    LabeledContent("Price Alerts",         value: draft.priceAlertsEnabled ? "On" : "Off")
                    LabeledContent("Watchlist Alerts",     value: draft.watchlistAlertsEnabled ? "On" : "Off")
                    LabeledContent("Holding Risk Alerts",  value: draft.holdingRiskAlertsEnabled ? "On" : "Off")
                    LabeledContent("Recommendation Alerts", value: draft.recommendationChangeAlertsEnabled ? "On" : "Off")
                }
            }
            .navigationTitle("Review Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Back") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Confirm") { onConfirm() } }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    let container = try! ModelContainerFactory.makeSharedContainer(isStoredInMemoryOnly: true)
    let env = AppEnvironment(modelContainer: container)
    NavigationStack { EditPreferencesView() }
        .environment(env)
}
