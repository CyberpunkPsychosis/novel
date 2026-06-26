import SwiftUI

/// 阅读器：纸感底 + 衬线正文 + 宽行距；翻章并记录阅读进度。
struct ReaderView: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    @State private var currentIndex: Int

    init(book: Book, startIndex: Int) {
        self.book = book
        _currentIndex = State(initialValue: startIndex)
    }

    private var chapter: Chapter? { book.chapters.first { $0.index == currentIndex } }
    private var ordered: [Int] { book.chapters.map { $0.index }.sorted() }
    private var pos: Int { ordered.firstIndex(of: currentIndex) ?? 0 }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.35)
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        Color.clear.frame(height: 1).id("top")
                        if let chapter {
                            Text(chapter.title).font(Theme.serif(22, .bold)).foregroundStyle(Theme.ink)
                            ForEach(Array(paragraphs(chapter.content).enumerated()), id: \.offset) { _, para in
                                if para == "---" {
                                    HStack { Spacer(); Image(systemName: "leaf").font(.caption).foregroundStyle(Theme.olive.opacity(0.6)); Spacer() }.padding(.vertical, 6)
                                } else {
                                    Text(para).font(Theme.serif(18)).foregroundStyle(Theme.ink.opacity(0.9)).lineSpacing(9)
                                }
                            }
                        } else {
                            Text("章节缺失").foregroundStyle(Theme.sub)
                        }
                        HStack {
                            Button { go(-1, proxy) } label: { Label("上一章", systemImage: "chevron.left") }
                                .disabled(pos == 0)
                            Spacer()
                            Button { go(1, proxy) } label: { Label("下一章", systemImage: "chevron.right") }
                                .disabled(pos >= ordered.count - 1)
                        }
                        .font(.subheadline).tint(Theme.terraDeep).padding(.top, 28)
                    }
                    .padding(22)
                }
            }
        }
        .navigationTitle("\(pos + 1) / \(ordered.count)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { store.markRead(bookID: book.id, chapterIndex: currentIndex) }
        .onChange(of: currentIndex) { _, newValue in
            store.markRead(bookID: book.id, chapterIndex: newValue)
        }
    }

    private func go(_ delta: Int, _ proxy: ScrollViewProxy) {
        let n = pos + delta
        guard n >= 0, n < ordered.count else { return }
        currentIndex = ordered[n]
        proxy.scrollTo("top", anchor: .top)
    }

    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
