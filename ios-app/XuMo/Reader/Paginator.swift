import UIKit

/// 一页内容：所属章节 + 该页富文本 + 页内序号。
struct ReaderPage: Identifiable {
    let id = UUID()
    let chapterIndex: Int
    let chapterTitle: String
    let attr: NSAttributedString
    let pageInChapter: Int
    let pagesInChapter: Int
}

enum Paginator {
    /// 文本区四周内边距（与 PageVC 的 textContainerInset 必须一致）。
    static let inset = UIEdgeInsets(top: 64, left: 28, bottom: 72, right: 28)

    /// 把整本书按当前字号/主题切成页（每章标题作为该章第一页的开头）。
    static func paginate(book: Book, settings: ReaderSettings, screen: CGSize) -> [ReaderPage] {
        let pageSize = CGSize(width: screen.width - inset.left - inset.right,
                              height: screen.height - inset.top - inset.bottom)
        guard pageSize.width > 50, pageSize.height > 50 else { return [] }

        var pages: [ReaderPage] = []
        for ch in book.chapters.sorted(by: { $0.index < $1.index }) {
            let full = NSMutableAttributedString()
            full.append(NSAttributedString(string: ch.title + "\n\n", attributes: settings.titleAttributes()))
            full.append(NSAttributedString(string: normalize(ch.content), attributes: settings.bodyAttributes()))
            let ranges = split(full, pageSize: pageSize)
            for (i, r) in ranges.enumerated() {
                pages.append(ReaderPage(chapterIndex: ch.index, chapterTitle: ch.title,
                                        attr: full.attributedSubstring(from: r),
                                        pageInChapter: i + 1, pagesInChapter: ranges.count))
            }
        }
        return pages
    }

    private static func normalize(_ s: String) -> String {
        s.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }.joined(separator: "\n")
    }

    /// TextKit：把一段富文本按页面尺寸切成字符 range 数组。
    private static func split(_ attr: NSAttributedString, pageSize: CGSize) -> [NSRange] {
        let storage = NSTextStorage(attributedString: attr)
        let layout = NSLayoutManager()
        storage.addLayoutManager(layout)
        var ranges: [NSRange] = []
        var consumedGlyphs = 0
        // 不断添加容器，直到所有字形排版完。
        while consumedGlyphs < layout.numberOfGlyphs {
            let container = NSTextContainer(size: pageSize)
            container.lineFragmentPadding = 0
            layout.addTextContainer(container)
            let glyphRange = layout.glyphRange(for: container)
            if glyphRange.length == 0 { break }
            let charRange = layout.characterRange(forGlyphRange: glyphRange, actualGlyphRange: nil)
            ranges.append(charRange)
            consumedGlyphs = NSMaxRange(glyphRange)
        }
        return ranges.isEmpty ? [NSRange(location: 0, length: attr.length)] : ranges
    }
}
