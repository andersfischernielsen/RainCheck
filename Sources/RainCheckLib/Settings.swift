import Foundation
import Security

enum Settings {
    static let service = "com.yourcompany.RainCheck"
    static let tokenAccount = "tomorrowio-token"

    private static let startLocationKey = "startLocation"
    private static let endLocationKey = "endLocation"

    static func saveApiKey(_ token: String) {
        save(value: token, account: tokenAccount)
    }

    static func getApiKey() -> String? {
        return get(account: tokenAccount)
    }

    static func saveToken(_ token: String) {
        saveApiKey(token)
    }

    static func getToken() -> String? {
        return getApiKey()
    }

    static func saveStartLocation(_ location: String) {
        UserDefaults.standard.set(location, forKey: startLocationKey)
    }

    static func getStartLocation() -> String? {
        return UserDefaults.standard.string(forKey: startLocationKey)
    }

    static func saveEndLocation(_ location: String) {
        UserDefaults.standard.set(location, forKey: endLocationKey)
    }

    static func getEndLocation() -> String? {
        return UserDefaults.standard.string(forKey: endLocationKey)
    }

    private static func save(value: String, account: String) {
        let data = value.data(using: .utf8)!

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
        ]

        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func get(account: String) -> String? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let result = SecItemCopyMatching(query as CFDictionary, &item)

        if result == errSecSuccess, let data = item as? Data {
            return String(data: data, encoding: .utf8)
        }
        return nil
    }
}
