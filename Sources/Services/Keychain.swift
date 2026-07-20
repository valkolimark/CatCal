import Foundation
import Security

/// Minimal Keychain wrapper for the one secret CatCal stores: the stable
/// Sign in with Apple user identifier. Kept in the Keychain rather than
/// `UserDefaults` because it's the key every record's `ownerID` hangs off —
/// it needs to survive backup/restore and stay out of plist dumps.
enum Keychain {
    enum Key: String {
        case appleUserID = "com.valkolimark.catcal.appleUserID"
    }

    static func set(_ value: String, for key: Key) {
        guard let data = value.data(using: .utf8) else { return }

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]

        let attributes: [String: Any] = [
            kSecValueData as String: data,
            // Available after first unlock so a background CloudKit sync can
            // still resolve the owner without the device being unlocked.
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
        ]

        let status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            SecItemAdd(query.merging(attributes) { current, _ in current } as CFDictionary, nil)
        }
    }

    static func get(_ key: Key) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]

        var item: CFTypeRef?
        guard SecItemCopyMatching(query as CFDictionary, &item) == errSecSuccess,
              let data = item as? Data,
              let value = String(data: data, encoding: .utf8)
        else {
            return nil
        }
        return value
    }

    static func remove(_ key: Key) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: key.rawValue
        ]
        SecItemDelete(query as CFDictionary)
    }
}
