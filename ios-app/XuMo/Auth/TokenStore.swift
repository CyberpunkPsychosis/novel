import Foundation
import Security

/// JWT 存储：内存缓存（当次会话必可用）+ Keychain（首选持久化）+ UserDefaults 兜底。
/// 未签名的模拟器 build 上 Keychain 可能写入失败，故加 UserDefaults 兜底，保证登录态稳。
enum TokenStore {
    private static let service = "app.xumo.jwt"
    private static let account = "current"
    private static let udKey = "XUMO_JWT"

    private static var cached: String?

    static var token: String? {
        get {
            if let c = cached { return c }
            if let k = keychainRead() { cached = k; return k }
            if let u = UserDefaults.standard.string(forKey: udKey) { cached = u; return u }
            return nil
        }
        set {
            cached = newValue
            if let v = newValue, !v.isEmpty {
                keychainWrite(v)
                UserDefaults.standard.set(v, forKey: udKey)
            } else {
                clear()
            }
        }
    }

    static func clear() {
        cached = nil
        UserDefaults.standard.removeObject(forKey: udKey)
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
    }

    // MARK: Keychain（best-effort）
    private static func keychainWrite(_ value: String) {
        SecItemDelete([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ] as CFDictionary)
        SecItemAdd([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: Data(value.utf8),
        ] as CFDictionary, nil)
    }

    private static func keychainRead() -> String? {
        var out: AnyObject?
        let status = SecItemCopyMatching([
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ] as CFDictionary, &out)
        guard status == errSecSuccess, let d = out as? Data else { return nil }
        return String(data: d, encoding: .utf8)
    }
}
