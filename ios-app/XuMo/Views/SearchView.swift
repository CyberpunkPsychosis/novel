import SwiftUI

/// 真实搜索：对本地书库按标题 / 作者 / 标签过滤。
struct SearchView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var query = ""
    @FocusState private var focused: Bool

    private var results: [Book] {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return [] }
        return store.books.filter { b in
            b.title.localizedCaseInsensitiveContains(q)
            || b.author.localizedCaseInsensitiveContains(q)
            || b.tags.contains { $0.localizedCaseInsensitiveContains(q) }
        }
    }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.45)
            VStack(spacing: 14) {
                // 搜索框
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.sub)
                    TextField("搜书名、作者、标签", text: $query)
                        .focused($focused).autocorrectionDisabled()
                    if !query.isEmpty {
                        Button { query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Theme.line) }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 11)
                .background(Theme.surface)
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1)).clipShape(Capsule())
                .padding(.horizontal, 16).padding(.top, 8)

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if query.isEmpty {
                            Text("试试搜「鉴宝」「言情」「观山海」…").font(.subheadline).foregroundStyle(Theme.sub)
                                .padding(.top, 24)
                            FlowTags(tags: suggestedTags) { query = $0 }
                        } else if results.isEmpty {
                            Text("没有匹配「\(query)」的作品。").font(.subheadline).foregroundStyle(Theme.sub).padding(.top, 24)
                        } else {
                            ForEach(results) { b in
                                NavigationLink(value: b.id) { SearchResultRow(book: b, rating: MockData.rating(b.id)) }
                                    .buttonStyle(.plain)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
        .navigationTitle("搜索")
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
        .onAppear { focused = true }
    }

    private var suggestedTags: [String] {
        Array(Set(store.books.flatMap { $0.tags })).sorted().prefix(10).map { $0 }
    }
}

private struct SearchResultRow: View {
    let book: Book
    let rating: Double
    var body: some View {
        HStack(spacing: 12) {
            CoverView(book: book, showTitle: false).frame(width: 44)
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title).font(Theme.serif(15, .semibold)).foregroundStyle(Theme.ink)
                Text(book.author).font(.caption2).foregroundStyle(Theme.sub)
                RatingStars(value: rating, size: 10)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.line)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

/// 简易标签流式布局
struct FlowTags: View {
    let tags: [String]
    let onTap: (String) -> Void
    var body: some View {
        FlexWrap(tags, spacing: 8) { t in
            Button { onTap(t) } label: { TagChip(text: t) }.buttonStyle(.plain)
        }
    }
}

/// 极简的自动换行容器
struct FlexWrap<Data: RandomAccessCollection, Content: View>: View where Data.Element: Hashable {
    let data: Data
    let spacing: CGFloat
    let content: (Data.Element) -> Content
    init(_ data: Data, spacing: CGFloat = 8, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data; self.spacing = spacing; self.content = content
    }
    var body: some View {
        var width = CGFloat.zero
        var height = CGFloat.zero
        return GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(Array(data), id: \.self) { item in
                    content(item)
                        .alignmentGuide(.leading) { d in
                            if abs(width - d.width) > geo.size.width { width = 0; height -= d.height + spacing }
                            let result = width
                            if item == data.last { width = 0 } else { width -= d.width + spacing }
                            return result
                        }
                        .alignmentGuide(.top) { _ in
                            let result = height
                            if item == data.last { height = 0 }
                            return result
                        }
                }
            }
        }
        .frame(height: 120)
    }
}
