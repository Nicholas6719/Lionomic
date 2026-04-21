import SwiftUI

/// Per-account recommendation override editor. Three pickers — each
/// carrying a "Use global setting" sentinel that maps to `nil` in the
/// persisted `AccountOverride` — plus Save / Cancel / Clear.
///
/// Surfaced from `AccountListView` via a contextMenu on each account row.
/// Matches the lightweight direct-save pattern used by MAlerts2's
/// `PriceAlertSheet`, rather than the heavier draft/review/confirm flow —
/// these are small scalar edits with their own explicit Save button.
struct AccountOverrideSheet: View {

    let account: Account
    @Environment(AppEnvironment.self) private var env
    @Environment(\.dismiss) private var dismiss

    @State private var riskSelection: RiskChoice = .useGlobal
    @State private var horizonSelection: HorizonChoice = .useGlobal
    @State private var cautionSelection: CautionChoice = .useGlobal
    @State private var loaded = false

    private var hasExistingOverride: Bool {
        env.profileRepository.override(for: account) != nil
    }

    private var globalProfile: InvestingProfile? {
        try? env.profileRepository.fetchProfile()
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text(account.displayName)
                        .font(.body.weight(.semibold))
                    Text(account.kind.displayName)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("Overrides replace the matching global profile field only for this account. Leave any picker on \"Use global setting\" to inherit the app-wide value.")
                }

                Section {
                    Picker("Risk Tolerance", selection: $riskSelection) {
                        Text(globalLabel(for: globalProfile?.riskTolerance.displayName))
                            .tag(RiskChoice.useGlobal)
                        ForEach(RiskTolerance.allCases, id: \.self) { option in
                            Text(option.displayName).tag(RiskChoice.override(option))
                        }
                    }
                    Picker("Investment Horizon", selection: $horizonSelection) {
                        Text(globalLabel(for: globalProfile?.horizonPreference.displayName))
                            .tag(HorizonChoice.useGlobal)
                        ForEach(HorizonPreference.allCases, id: \.self) { option in
                            Text(option.displayName).tag(HorizonChoice.override(option))
                        }
                    }
                    Picker("Caution Bias", selection: $cautionSelection) {
                        Text(globalLabel(for: globalProfile?.cautionBias.displayName))
                            .tag(CautionChoice.useGlobal)
                        ForEach(CautionBias.allCases, id: \.self) { option in
                            Text(option.displayName).tag(CautionChoice.override(option))
                        }
                    }
                }

                if hasExistingOverride {
                    Section {
                        Button(role: .destructive) {
                            try? env.profileRepository.clearOverride(for: account)
                            dismiss()
                        } label: {
                            Text("Clear overrides")
                        }
                    }
                }
            }
            .navigationTitle("Account Overrides")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                }
            }
            .task {
                guard !loaded else { return }
                loadExisting()
                loaded = true
            }
        }
    }

    // MARK: - Load / save

    private func loadExisting() {
        guard let existing = env.profileRepository.override(for: account) else { return }
        if let r = existing.riskTolerance { riskSelection = .override(r) }
        if let h = existing.horizonPreference { horizonSelection = .override(h) }
        if let c = existing.cautionBias { cautionSelection = .override(c) }
    }

    private func save() {
        try? env.profileRepository.setOverride(
            for: account,
            riskTolerance: riskSelection.value,
            horizonPreference: horizonSelection.value,
            cautionBias: cautionSelection.value
        )
        dismiss()
    }

    private func globalLabel(for value: String?) -> String {
        if let value {
            return "Use global (\(value))"
        }
        return "Use global setting"
    }
}

// MARK: - Picker tag types

/// SwiftUI Picker requires Hashable-tagged choices. Wrapping each enum
/// in a two-case `override/useGlobal` choice type keeps the nil branch
/// representable without bolting an optional onto the picker selection.

private enum RiskChoice: Hashable {
    case useGlobal
    case override(RiskTolerance)

    var value: RiskTolerance? {
        switch self {
        case .useGlobal: return nil
        case .override(let v): return v
        }
    }
}

private enum HorizonChoice: Hashable {
    case useGlobal
    case override(HorizonPreference)

    var value: HorizonPreference? {
        switch self {
        case .useGlobal: return nil
        case .override(let v): return v
        }
    }
}

private enum CautionChoice: Hashable {
    case useGlobal
    case override(CautionBias)

    var value: CautionBias? {
        switch self {
        case .useGlobal: return nil
        case .override(let v): return v
        }
    }
}
