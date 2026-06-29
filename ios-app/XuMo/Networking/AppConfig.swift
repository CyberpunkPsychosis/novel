import Foundation

/// 后端地址配置。
/// - DEBUG（模拟器）默认打本机 docker 的 http://localhost:3000
/// - RELEASE 走生产域名（备案后换成你的 api.<域名>）
/// 也可在不重编的情况下用 UserDefaults "XUMO_API_BASE" 覆盖（指向 ECS 公网 IP）。
enum AppConfig {
    /// 真机默认指向"同 WiFi 下 Mac 的局域网 IP"。换了网络（WiFi/热点）此 IP 会变，
    /// 改这里即可；或在设置页用 XUMO_API_BASE 覆盖，不必重编。
    static let macLANBaseURL = "http://172.20.10.3:3000"

    static var baseURL: String {
        if let override = UserDefaults.standard.string(forKey: "XUMO_API_BASE"),
           !override.isEmpty {
            return override.hasSuffix("/") ? String(override.dropLast()) : override
        }
        #if targetEnvironment(simulator)
        return "http://localhost:3000"          // 模拟器跑在 Mac 上，直连 localhost
        #else
        return macLANBaseURL                     // 真机走 Mac 局域网 IP（同 WiFi）
        #endif
    }
}
