import Foundation
import Observation

/// Drives ApiKeysView. Draft fields start empty — we never display saved key values.
@Observable
@MainActor
final class ApiKeysViewModel {

    // Draft state
    var draftTwelveDataKey: String = ""
    var draftFinnhubKey: String = ""
    var draftAnthropicKey: String = ""

    // Display state — presence only, never the actual key value
    private(set) var twelveDataKeyIsSaved: Bool = false
    private(set) var finnhubKeyIsSaved: Bool = false
    private(set) var anthropicKeyIsSaved: Bool = false

    var showingReviewSheet: Bool = false

    private var keychain: KeychainService?

    func configure(keychain: KeychainService) {
        self.keychain = keychain
        refreshSavedState()
    }

    var canRequestReview: Bool {
        !draftTwelveDataKey.trimmingCharacters(in: .whitespaces).isEmpty ||
        !draftFinnhubKey.trimmingCharacters(in: .whitespaces).isEmpty ||
        !draftAnthropicKey.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func requestReview() {
        showingReviewSheet = true
    }

    /// Saves non-empty drafts, then clears draft fields. Only call after user confirmation.
    func confirmSave() {
        guard let keychain else { return }

        let td = draftTwelveDataKey.trimmingCharacters(in: .whitespaces)
        let fh = draftFinnhubKey.trimmingCharacters(in: .whitespaces)
        let an = draftAnthropicKey.trimmingCharacters(in: .whitespaces)

        if !td.isEmpty { try? keychain.save(td, for: KeychainService.twelveDataApiKeyIdentifier) }
        if !fh.isEmpty { try? keychain.save(fh, for: KeychainService.finnhubApiKeyIdentifier) }
        if !an.isEmpty { try? keychain.save(an, for: KeychainService.anthropicApiKeyIdentifier) }

        draftTwelveDataKey = ""
        draftFinnhubKey    = ""
        draftAnthropicKey  = ""
        showingReviewSheet = false
        refreshSavedState()
    }

    func deleteTwelveDataKey() {
        keychain?.remove(identifier: KeychainService.twelveDataApiKeyIdentifier)
        refreshSavedState()
    }

    func deleteFinnhubKey() {
        keychain?.remove(identifier: KeychainService.finnhubApiKeyIdentifier)
        refreshSavedState()
    }

    func deleteAnthropicKey() {
        keychain?.remove(identifier: KeychainService.anthropicApiKeyIdentifier)
        refreshSavedState()
    }

    private func refreshSavedState() {
        guard let keychain else { return }
        twelveDataKeyIsSaved = keychain.hasValue(for: KeychainService.twelveDataApiKeyIdentifier)
        finnhubKeyIsSaved    = keychain.hasValue(for: KeychainService.finnhubApiKeyIdentifier)
        anthropicKeyIsSaved  = keychain.hasValue(for: KeychainService.anthropicApiKeyIdentifier)
    }
}
