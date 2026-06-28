import Foundation

/// 后端地址配置。
/// - DEBUG（模拟器）默认打本机 docker 的 http://localhost:3000
/// - RELEASE 走生产域名（备案后换成你的 api.<域名>）
/// 也可在不重编的情况下用 UserDefaults "XUMO_API_BASE" 覆盖（指向 ECS 公网 IP）。
enum AppConfig {
    static var baseURL: String {
        if let override = UserDefaults.standard.string(forKey: "XUMO_API_BASE"),
           !override.isEmpty {
            return override.hasSuffix("/") ? String(override.dropLast()) : override
        }
        #if DEBUG
        return "http://localhost:3000"
        #else
        return "https://api.example.com"   // TODO: 备案后换成真实域名
        #endif
    }
}
