import SwiftUI
import UIKit

/// 阅读主题（纸/护眼/夜间）。
enum ReaderTheme: String, CaseIterable, Identifiable {
    case paper, sepia, dark
    var id: String { rawValue }
    var label: String { self == .paper ? "纸张" : self == .sepia ? "护眼" : "夜间" }

    var bg: UIColor {
        switch self {
        case .paper: return UIColor(red: 0.976, green: 0.961, blue: 0.945, alpha: 1) // #F9F5F1
        case .sepia: return UIColor(red: 0.953, green: 0.918, blue: 0.835, alpha: 1)
        case .dark:  return UIColor(red: 0.110, green: 0.110, blue: 0.118, alpha: 1)
        }
    }
    var text: UIColor {
        switch self {
        case .dark: return UIColor(white: 0.86, alpha: 1)
        default:    return UIColor(red: 0.102, green: 0.137, blue: 0.196, alpha: 1) // ink #1A2332
        }
    }
    var swiftBG: Color { Color(bg) }
    var swiftText: Color { Color(text) }
}

/// 阅读偏好（字号/行距/主题/翻页 or 滚动），持久化到 UserDefaults。
/// 用 @Published+didSet（而非 @AppStorage）以确保在 ObservableObject 里能正确发布变更。
final class ReaderSettings: ObservableObject {
    private let d = UserDefaults.standard
    @Published var fontSize: Double { didSet { d.set(fontSize, forKey: "reader.fontSize") } }
    @Published var lineSpacing: Double { didSet { d.set(lineSpacing, forKey: "reader.lineSpacing") } }
    @Published var theme: ReaderTheme { didSet { d.set(theme.rawValue, forKey: "reader.theme") } }
    @Published var scrollMode: Bool { didSet { d.set(scrollMode, forKey: "reader.scrollMode") } }

    init() {
        fontSize = d.object(forKey: "reader.fontSize") as? Double ?? 19
        lineSpacing = d.object(forKey: "reader.lineSpacing") as? Double ?? 9
        theme = ReaderTheme(rawValue: d.string(forKey: "reader.theme") ?? "") ?? .paper
        scrollMode = d.bool(forKey: "reader.scrollMode")
    }

    /// 正文段落属性（衬线 + 行距 + 首行缩进）。
    func bodyAttributes() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.lineSpacing = lineSpacing
        para.paragraphSpacing = lineSpacing * 1.4
        para.firstLineHeadIndent = fontSize * 2   // 首行缩进两字
        return [
            .font: UIFont(name: "Songti SC", size: fontSize) ?? UIFont.systemFont(ofSize: fontSize),
            .foregroundColor: theme.text,
            .paragraphStyle: para,
        ]
    }
    func titleAttributes() -> [NSAttributedString.Key: Any] {
        let para = NSMutableParagraphStyle()
        para.paragraphSpacing = fontSize
        return [
            .font: UIFont(name: "Songti SC", size: fontSize + 6) ?? UIFont.boldSystemFont(ofSize: fontSize + 6),
            .foregroundColor: theme.text,
            .paragraphStyle: para,
        ]
    }
}
