import SwiftUI

/// 阅读器：按章翻页，底部上一章/下一章。
struct ReaderView: View {
    let book: Book
    @State private var currentIndex: Int

    init(book: Book, startIndex: Int) {
        self.book = book
        _currentIndex = State(initialValue: startIndex)
    }

    private var chapter: Chapter? {
        book.chapters.first { $0.index == currentIndex }
    }
    private var ordered: [Int] { book.chapters.map { $0.index }.sorted() }
    private var pos: Int { ordered.firstIndex(of: currentIndex) ?? 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Color.clear.frame(height: 1).id("top")
                    if let chapter {
                        Text(chapter.title)
                            .font(.title3.bold())
                        ForEach(paragraphs(chapter.content), id: \.self) { para in
                            if para == "---" {
                                Divider().padding(.vertical, 4)
                            } else {
                                Text(para)
                                    .font(.system(size: 18))
                                    .lineSpacing(7)
                            }
                        }
                    } else {
                        Text("章节缺失")
                    }

                    // 翻章
                    HStack {
                        Button {
                            if pos > 0 { currentIndex = ordered[pos - 1]; proxy.scrollTo("top", anchor: .top) }
                        } label: { Label("上一章", systemImage: "chevron.left") }
                            .disabled(pos == 0)
                        Spacer()
                        Button {
                            if pos < ordered.count - 1 { currentIndex = ordered[pos + 1]; proxy.scrollTo("top", anchor: .top) }
                        } label: { Label("下一章", systemImage: "chevron.right") }
                            .disabled(pos >= ordered.count - 1)
                    }
                    .font(.subheadline)
                    .padding(.top, 24)
                }
                .padding(20)
            }
        }
        .navigationTitle("\(pos + 1)/\(ordered.count)")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func paragraphs(_ text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}
