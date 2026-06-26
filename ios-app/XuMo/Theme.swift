import SwiftUI
import UIKit

/// 「书艺之阁 / The Artful Shelf」设计系统：暖纸底 + 复古书籍色 + 衬线标题。
enum Theme {
    // 色板（取自参考 UI Kit：陶土红 / 鼠尾草绿 / 赭黄 / 墨 / 米纸）
    static let bg        = Color(hex: "#F3ECDF") // 暖米纸背景
    static let surface   = Color(hex: "#FBF6EC") // 卡片/浅面
    static let ink       = Color(hex: "#2E2A24") // 主文字（墨）
    static let inkSoft   = Color(hex: "#7A6F5E") // 次文字
    static let terracotta = Color(hex: "#BE5A39") // 主色·陶土红
    static let sage      = Color(hex: "#4C6B5D") // 副色·鼠尾草绿
    static let ochre     = Color(hex: "#C8973F") // 点缀·赭黄
    static let line      = Color(hex: "#E2D8C6") // 分隔/描边

    /// 衬线字体（标题/书名用，营造书卷气）
    static func serif(_ size: CGFloat, _ weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// 配置导航栏 / 标签栏外观：米纸底、墨色字、衬线标题。
    static func applyAppearance() {
        let inkUI = UIColor(ink)

        let nav = UINavigationBarAppearance()
        nav.configureWithOpaqueBackground()
        nav.backgroundColor = UIColor(bg)
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

/// 统一的小标题（带一片叶子点缀，呼应植物线描风）。
struct SectionHeader: View {
    let title: String
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "leaf")
                .font(.caption)
                .foregroundStyle(Theme.sage)
            Text(title)
                .font(Theme.serif(20, .semibold))
                .foregroundStyle(Theme.ink)
            Spacer()
        }
    }
}

/// 复古胶囊标签。
struct TagChip: View {
    let text: String
    var color: Color = Theme.sage
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.14))
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
            .clipShape(Capsule())
    }
}
