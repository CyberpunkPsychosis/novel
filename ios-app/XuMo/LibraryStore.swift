import Foundation
import SwiftUI

/// 数据仓库：内置种子书 + 用户改编/续写 + 阅读进度，本地持久化。
final class LibraryStore: ObservableObject {
    @Published private(set) var books: [Book] = []
    /// bookID -> 最近读到的章节 index
    @Published private(set) var readingProgress: [String: Int] = [:]

    private let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    private var userBooksURL: URL { docs.appendingPathComponent("userBooks.json") }
    private var progressURL: URL { docs.appendingPathComponent("progress.json") }

    init() {
        reload()
        loadProgress()
        if readingProgress.isEmpty { seedDemoProgress() }
    }

    func reload() {
        var all = Self.loadSeed()
        all.append(contentsOf: loadUserBooks())
        books = all
    }

    // MARK: 查询
    func book(id: String) -> Book? { books.first { $0.id == id } }
    var seedAndPublished: [Book] { books }
    var myCreations: [Book] { books.filter { $0.isUserCreated } }
    func forks(of bookID: String) -> [Book] { books.filter { $0.forkOf == bookID } }
    func forkCount(of bookID: String) -> Int { forks(of: bookID).count }

    // MARK: 阅读进度
    func markRead(bookID: String, chapterIndex: Int) {
        readingProgress[bookID] = chapterIndex
        saveProgress()
    }
    func lastReadIndex(_ bookID: String) -> Int? { readingProgress[bookID] }

    /// 已读进度 0...1
    func fraction(for book: Book) -> Double {
        guard let last = readingProgress[book.id], !book.chapters.isEmpty else { return 0 }
        let idxs = book.chapters.map { $0.index }.sorted()
        let pos = idxs.firstIndex(of: last) ?? 0
        return Double(pos + 1) / Double(idxs.count)
    }
    func caption(for book: Book) -> String {
        guard let last = readingProgress[book.id] else { return book.author }
        let idxs = book.chapters.map { $0.index }.sorted()
        let pos = (idxs.firstIndex(of: last) ?? 0) + 1
        return "\(book.author) · \(pos) / \(idxs.count) 章"
    }
    /// 在读书目（有进度的种子书，按最近读优先粗排）
    var inProgressBooks: [Book] {
        books.filter { readingProgress[$0.id] != nil && !$0.isUserCreated }
    }

    // MARK: 改编 / 续写
    enum ForkMode { case continuation, adaptation }

    @discardableResult
    func createFork(from parent: Book, mode: ForkMode, fromChapter: Int,
                    newChapterTitle: String, newContent: String, myPenName: String) -> Book {
        var base: [Chapter]
        switch mode {
        case .continuation: base = parent.chapters
        case .adaptation:   base = parent.chapters.filter { $0.index <= fromChapter }
        }
        let nextIndex = (base.map { $0.index }.max() ?? 0) + 1
        let t = newChapterTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        base.append(Chapter(index: nextIndex,
                            title: t.isEmpty ? "第\(nextIndex)章" : t,
                            content: newContent.trimmingCharacters(in: .whitespacesAndNewlines)))
        let label = (mode == .continuation) ? "续写" : "改编"
        let new = Book(
            id: "user-\(UUID().uuidString.prefix(8))",
            title: "\(parent.title)·\(label)",
            author: myPenName.isEmpty ? "我" : myPenName,
            blurb: "\(label)自《\(parent.title)》。" + String(parent.blurb.prefix(40)),
            tags: parent.tags, tagline: "\(label)自《\(parent.title)》",
            coverColors: parent.coverColors, coverAccent: parent.coverAccent,
            status: "创作中", forkOf: parent.id,
            forkFromChapter: (mode == .adaptation) ? fromChapter : nil,
            isUserCreated: true, chapters: base)
        var mine = loadUserBooks(); mine.append(new); saveUserBooks(mine); reload()
        return new
    }

    func deleteUserBook(id: String) {
        var mine = loadUserBooks(); mine.removeAll { $0.id == id }; saveUserBooks(mine); reload()
    }

    // MARK: 持久化
    private static func loadSeed() -> [Book] {
        guard let url = Bundle.main.url(forResource: "seed", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return [] }
        return (try? JSONDecoder().decode([Book].self, from: data)) ?? []
    }
    private func loadUserBooks() -> [Book] {
        guard let data = try? Data(contentsOf: userBooksURL) else { return [] }
        return (try? JSONDecoder().decode([Book].self, from: data)) ?? []
    }
    private func saveUserBooks(_ b: [Book]) {
        if let data = try? JSONEncoder().encode(b) { try? data.write(to: userBooksURL, options: .atomic) }
    }
    private func loadProgress() {
        guard let data = try? Data(contentsOf: progressURL) else { return }
        readingProgress = (try? JSONDecoder().decode([String: Int].self, from: data)) ?? [:]
    }
    private func saveProgress() {
        if let data = try? JSONEncoder().encode(readingProgress) { try? data.write(to: progressURL, options: .atomic) }
    }
    /// 首次启动给几本书预置进度，让"继续阅读/在读"不空。
    private func seedDemoProgress() {
        let demo = ["huisheng": 6, "fayan": 28, "yimian": 4]
        for (id, idx) in demo where book(id: id) != nil { readingProgress[id] = idx }
        saveProgress()
    }
}

// MARK: 颜色工具
extension Color {
    init(hex: String) {
        let s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        var v: UInt64 = 0
        Scanner(string: s).scanHexInt64(&v)
        if s.count == 6 {
            self = Color(red: Double((v & 0xFF0000) >> 16)/255,
                         green: Double((v & 0x00FF00) >> 8)/255,
                         blue: Double(v & 0x0000FF)/255)
        } else { self = Color(red: 0.1, green: 0.1, blue: 0.12) }
    }
}
