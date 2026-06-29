import SwiftUI

/// 阅读器：默认仿真翻页（pageCurl，一章自动分多页），可在设置切上下滚动。
struct ReaderView: View {
    @EnvironmentObject var store: LibraryStore
    @StateObject private var settings = ReaderSettings()
    let book: Book
    @State private var startIndex: Int
    @State private var hud = ""
    @State private var showSettings = false
    @State private var lastReported = -1

    init(book: Book, startIndex: Int) {
        self.book = book
        _startIndex = State(initialValue: startIndex)
    }

    var body: some View {
        ZStack {
            settings.theme.swiftBG.ignoresSafeArea()
            if settings.scrollMode {
                ScrollChapterReader(book: book, startIndex: startIndex, settings: settings) { reportChapter($0) }
            } else {
                PagedReaderView(
                    book: book,
                    fontSize: settings.fontSize,
                    lineSpacing: settings.lineSpacing,
                    theme: settings.theme,
                    startChapter: startIndex,
                    onChapter: { reportChapter($0) },
                    onHUD: { hud = $0 }
                )
            }
        }
        .navigationTitle(settings.scrollMode ? book.title : hud)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { showSettings = true } label: {
                    Image(systemName: "textformat.size").foregroundStyle(settings.theme.swiftText)
                }
            }
        }
        .toolbarBackground(settings.theme.swiftBG, for: .navigationBar)
        .sheet(isPresented: $showSettings) {
            ReaderSettingsSheet(settings: settings)
                .presentationDetents([.height(300)])
        }
        .onAppear { store.markRead(bookID: book.id, chapterIndex: startIndex) }
    }

    private func reportChapter(_ idx: Int) {
        guard idx != lastReported else { return }
        lastReported = idx
        store.markRead(bookID: book.id, chapterIndex: idx)
    }
}

/// 设置面板：字号 / 行距 / 主题 / 翻页方式。
struct ReaderSettingsSheet: View {
    @ObservedObject var settings: ReaderSettings
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            Form {
                Section("字号") {
                    HStack {
                        Button { settings.fontSize = max(14, settings.fontSize - 1) } label: { Text("A").font(.subheadline) }
                        Slider(value: $settings.fontSize, in: 14...30, step: 1)
                        Button { settings.fontSize = min(30, settings.fontSize + 1) } label: { Text("A").font(.title3) }
                    }.buttonStyle(.bordered)
                }
                Section("行距") {
                    Slider(value: $settings.lineSpacing, in: 2...18, step: 1)
                }
                Section("主题") {
                    Picker("主题", selection: Binding(get: { settings.theme }, set: { settings.theme = $0 })) {
                        ForEach(ReaderTheme.allCases) { Text($0.label).tag($0) }
                    }.pickerStyle(.segmented)
                }
                Section {
                    Toggle("上下滚动模式", isOn: $settings.scrollMode)
                } footer: { Text("关闭为仿真翻页（左右翻），开启为传统上下滚动。") }
            }
            .navigationTitle("阅读设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("完成") { dismiss() } } }
        }
    }
}

/// 上下滚动备选模式（按章）。
struct ScrollChapterReader: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    @State private var currentIndex: Int
    @ObservedObject var settings: ReaderSettings
    let onChapter: (Int) -> Void

    init(book: Book, startIndex: Int, settings: ReaderSettings, onChapter: @escaping (Int) -> Void) {
        self.book = book; self.settings = settings; self.onChapter = onChapter
        _currentIndex = State(initialValue: startIndex)
    }

    private var chapter: Chapter? { book.chapters.first { $0.index == currentIndex } }
    private var ordered: [Int] { book.chapters.map { $0.index }.sorted() }
    private var pos: Int { ordered.firstIndex(of: currentIndex) ?? 0 }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: settings.lineSpacing) {
                    Color.clear.frame(height: 1).id("top")
                    if let chapter {
                        Text(chapter.title).font(.system(size: settings.fontSize + 6, weight: .bold))
                            .foregroundStyle(settings.theme.swiftText)
                        ForEach(Array(paragraphs(chapter.content).enumerated()), id: \.offset) { _, para in
                            Text(para).font(.custom("Songti SC", size: settings.fontSize))
                                .foregroundStyle(settings.theme.swiftText).lineSpacing(settings.lineSpacing)
                        }
                    }
                    HStack {
                        Button { go(-1, proxy) } label: { Label("上一章", systemImage: "chevron.left") }.disabled(pos == 0)
                        Spacer()
                        Button { go(1, proxy) } label: { Label("下一章", systemImage: "chevron.right") }.disabled(pos >= ordered.count - 1)
                    }.font(.subheadline).tint(Theme.terraDeep).padding(.top, 24)
                }
                .padding(22)
            }
            .onAppear { onChapter(currentIndex) }
            .onChange(of: currentIndex) { _, v in onChapter(v) }
        }
    }
    private func go(_ d: Int, _ proxy: ScrollViewProxy) {
        let n = pos + d; guard n >= 0, n < ordered.count else { return }
        currentIndex = ordered[n]; proxy.scrollTo("top", anchor: .top)
    }
    private func paragraphs(_ t: String) -> [String] {
        t.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
}
