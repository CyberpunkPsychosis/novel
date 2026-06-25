import SwiftUI

/// 发现页：书架网格。
struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 16)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(store.seedAndPublished) { book in
                    NavigationLink(value: book.id) {
                        BookCard(book: book)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
        }
        .navigationTitle("发现")
        .navigationDestination(for: String.self) { id in
            if let b = store.book(id: id) { BookDetailView(book: b) }
        }
    }
}

struct BookCard: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverView(book: book)
            Text(book.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(book.author).font(.caption2).foregroundStyle(.secondary)
                if book.forkOf != nil {
                    Text("改编").font(.caption2)
                        .padding(.horizontal, 5).padding(.vertical, 1)
                        .background(Color(hex: book.coverAccent).opacity(0.25))
                        .clipShape(Capsule())
                }
                Spacer()
                let n = store.forkCount(of: book.id)
                if n > 0 {
                    Label("\(n)", systemImage: "arrow.triangle.branch")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
    }
}

/// 我的创作页。
struct MyCreationsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        Group {
            if store.myCreations.isEmpty {
                ContentUnavailableView(
                    "还没有你的创作",
                    systemImage: "pencil.and.outline",
                    description: Text("去「发现」里挑一本书，点「改编 / 续写」，就能开出属于你的支线。")
                )
            } else {
                List {
                    ForEach(store.myCreations) { book in
                        NavigationLink(value: book.id) {
                            HStack(spacing: 12) {
                                CoverView(book: book, showTitle: false)
                                    .frame(width: 48)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title).font(.headline)
                                    Text(book.tagline).font(.caption).foregroundStyle(.secondary)
                                    Text("\(book.chapters.count) 章 · \(book.status)")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onDelete { idx in
                        idx.map { store.myCreations[$0].id }.forEach(store.deleteUserBook)
                    }
                }
            }
        }
        .navigationTitle("我的创作")
        .navigationDestination(for: String.self) { id in
            if let b = store.book(id: id) { BookDetailView(book: b) }
        }
    }
}
