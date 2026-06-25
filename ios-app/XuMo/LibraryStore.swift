import Foundation
import SwiftUI

/// 全局数据仓库：加载内置种子书 + 用户在本机创建的改编/续写，并负责持久化。
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []

    /// 用户创建的书单独存到 Documents/userBooks.json，种子书只读。
    private let userBooksURL: URL = {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return dir.appendingPathComponent("userBooks.json")
    }()

    init() { reload() }

    func reload() {
        var all = Self.loadSeed()
        all.append(contentsOf: loadUserBooks())
        books = all
    }

    // MARK: 查询

    func book(id: String) -> Book? { books.first { $0.id == id } }

    var seedAndPublished: [Book] {
        // "发现"页：展示所有书（种子 + 用户已发布的改编）。
        books
    }

    var myCreations: [Book] {
        books.filter { $0.isUserCreated }
    }

    /// 某本书被改编/续写出的子书。
    func forks(of bookID: String) -> [Book] {
        books.filter { $0.forkOf == bookID }
    }

    func forkCount(of bookID: String) -> Int { forks(of: bookID).count }

    // MARK: 创建改编 / 续写

    enum ForkMode { case continuation, adaptation }

    /// 基于某本书创建一个分叉。
    /// - continuation 续写：复制父书全部章节，在末尾追加 newChapterTitle/newContent。
    /// - adaptation 改编：保留父书第 1…fromChapter 章，再接上新章节（另起支线）。
    @discardableResult
    func createFork(from parent: Book,
                    mode: ForkMode,
                    fromChapter: Int,
                    newChapterTitle: String,
                    newContent: String,
                    myPenName: String) -> Book {
        var base: [Chapter]
        switch mode {
        case .continuation:
            base = parent.chapters
        case .adaptation:
            base = parent.chapters.filter { $0.index <= fromChapter }
        }
        let nextIndex = (base.map { $0.index }.max() ?? 0) + 1
        let title = newChapterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let chapter = Chapter(index: nextIndex,
                              title: title.isEmpty ? "第\(nextIndex)章" : title,
                              content: newContent.trimmingCharacters(in: .whitespacesAndNewlines))
        base.append(chapter)

        let label = (mode == .continuation) ? "续写" : "改编"
        let new = Book(
            id: "user-\(UUID().uuidString.prefix(8))",
            title: "\(parent.title)·\(label)",
            author: myPenName.isEmpty ? "我" : myPenName,
            blurb: "\(label)自《\(parent.title)》。" + String(parent.blurb.prefix(40)),
            tags: parent.tags,
            tagline: "\(label)自《\(parent.title)》",
            coverColors: parent.coverColors,
            coverAccent: parent.coverAccent,
            status: "创作中",
            forkOf: parent.id,
            forkFromChapter: (mode == .adaptation) ? fromChapter : nil,
            isUserCreated: true,
            chapters: base
        )
        var mine = loadUserBooks()
        mine.append(new)
        saveUserBooks(mine)
        reload()
        return new
    }

    func deleteUserBook(id: String) {
        var mine = loadUserBooks()
        mine.removeAll { $0.id == id }
        saveUserBooks(mine)
        reload()
    }

    // MARK: 持久化

    private static func loadSeed() -> [Book] {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            assertionFailure("找不到内置 seed.json，请确认它被加进了 App Target 的资源里")
            return []
        }
        do { return try JSONDecoder().decode([Book].self, from: data) }
        catch { assertionFailure("seed.json 解析失败: \(error)"); return [] }
    }

    private func loadUserBooks() -> [Book] {
        guard let data = try? Data(contentsOf: userBooksURL) else { return [] }
        return (try? JSONDecoder().decode([Book].self, from: data)) ?? []
    }

    private func saveUserBooks(_ books: [Book]) {
        if let data = try? JSONEncoder().encode(books) {
            try? data.write(to: userBooksURL, options: .atomic)
        }
    }
}

// MARK: - 颜色工具

extension Color {
    /// 从 "#RRGGBB" 生成 Color。
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        let r, g, b: Double
        if s.count == 6 {
            r = Double((v & 0xFF0000) >> 16) / 255
            g = Double((v & 0x00FF00) >> 8) / 255
            b = Double(v & 0x0000FF) / 255
        } else { r = 0.1; g = 0.1; b = 0.12 }
        self = Color(red: r, green: g, blue: b)
    }
}
