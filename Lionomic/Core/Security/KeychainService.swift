import Foundation
import Security

/// Manages secure, device-local storage of API keys.
///
/// All values use `kSecAttrAccessibleWhenUnlockedThisDeviceOnly`, which means:
///   - Keys are never synced to iCloud Keychain.
///   - Keys do not survive a device restore or app reinstall.
///   - If a key is missing after reinstall, the user simply re-enters it.
final class KeychainService: Sendable {

    // MARK: - Key identifiers

    nonisolated static let twelveDataApiKeyIdentifier = "lionomic.twelvedata.apikey"
    nonisolated static let finnhubApiKeyIdentifier    = "lionomic.finnhub.apikey"

    nonisolated init() {}

    // MARK: - Save

    nonisolated func save(_ value: String, for identifier: String) throws {
        let data = Data(value.utf8)
        removeItem(for: identifier)

        let query: [CFString: Any] = [
            kSecClass:          kSecClassGenericPassword,
            kSecAttrAccount:    identifier,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            kSecValueData:      data
        ]

        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.writeFailed(status: status)
        }
    }

    // MARK: - Load

    nonisolated func load(identifier: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: identifier,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard
            status == errSecSuccess,
            let data = result as? Data,
            let string = String(data: data, encoding: .utf8)
        else { return nil }

        return string
    }

    // MARK: - Presence check

    nonisolated func hasValue(for identifier: String) -> Bool {
        guard let value = load(identifier: identifier) else { return false }
        return !value.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Delete

    nonisolated func remove(identifier: String) {
        removeItem(for: identifier)
    }

    // MARK: - Private

    nonisolated private func removeItem(for identifier: String) {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: identifier
        ]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - Errors

enum KeychainError: LocalizedError, Equatable {
    case writeFailed(status: OSStatus)

    var errorDescription: String? {
        switch self {
        case .writeFailed(let status):
            return "Keychain write failed (OSStatus \(status))."
        }
    }
}
