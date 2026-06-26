import SwiftUI
import UIKit

/// 「品·书阁 / The Artful Shelf」设计系统——配色精确取自 UI Kit。
enum Theme {
    static let cream     = Color(hex: "#F9F5F1") // 背景
    static let surface   = Color(hex: "#FBF8F3") // 卡片面
    static let blue      = Color(hex: "#1A2332") // Deep Blue：深色卡 / 近墨
    static let terracotta = Color(hex: "#B17D6B") // 柔陶土
    static let terraDeep = Color(hex: "#A65A3C") // 强调 / 激活态（更可读）
    static let bronze    = Color(hex: "#C7A17A") // 主按钮 / 星级
    static let olive     = Color(hex: "#6E7042") // 点缀
    static let line      = Color(hex: "#E7DECF") // 描边 / 分隔
    static let ink       = Color(hex: "#2B2A26") // 主文字
    static let sub       = Color(hex: "#9A8F7E") // 次文字

    /// 衬线（书名 / 作者 / 区块标题）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// 导航栏 / 标签栏外观：米纸底、墨色衬线标题。
    static func applyAppearance() {
        let inkUI = UIColor(ink)
        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(cream)
        nav.shadowColor = .clear
        if let d = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .largeTitle).withDesign(.serif) {
            nav.largeTitleTextAttributes = [.foregroundColor: inkUI, .font: UIFont(descriptor: d, size: 0)]
        }
        if let d = UIFontDescriptor.preferredFontDescriptor(withTextStyle: .headline).withDesign(.serif) {
            nav.titleTextAttributes = [.foregroundColor: inkUI, .font: UIFont(descriptor: d, size: 0)]
        }
        UINavigationBar.appearance().standardAppearance = nav
        UINavigationBar.appearance().scrollEdgeAppearance = nav
        UINavigationBar.appearance().compactAppearance = nav

        let tab = UITabBarAppearance()
        tab.configureWithOpaqueBackground()
        tab.backgroundColor = UIColor(surface)
        UITabBar.appearance().standardAppearance = tab
        UITabBar.appearance().scrollEdgeAppearance = tab
    }
}
