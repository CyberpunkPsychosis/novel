import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    @State private var showFork = false

    private var parent: Book? { book.forkOf.flatMap { store.book(id: $0) } }
    private var children: [Book] { store.forks(of: book.id) }

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 头部
                    HStack(alignment: .top, spacing: 16) {
                        CoverView(book: book).frame(width: 128)
                        VStack(alignment: .leading, spacing: 8) {
                            Text(book.title).font(Theme.serif(24, .bold)).foregroundStyle(Theme.ink)
                            Text(book.author).font(.subheadline).foregroundStyle(Theme.inkSoft)
                            if !book.status.isEmpty { TagChip(text: book.status, color: Theme.ochre) }
                            if let parent {
                                NavigationLink(value: parent.id) {
                                    Label("改编自《\(parent.title)》", systemImage: "arrow.uturn.backward")
                                        .font(.caption).foregroundStyle(Theme.terracotta)
                                }
                            }
                        }
                        Spacer()
                    }

                    if !book.tags.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack { ForEach(book.tags, id: \.self) { TagChip(text: $0) } }
                        }
                    }

                    Text(book.blurb).font(.body).foregroundStyle(Theme.ink.opacity(0.85)).lineSpacing(4)

                    // 核心操作
                    Button { showFork = true } label: {
                        Label("改编 / 续写这本书", systemImage: "arrow.triangle.branch")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.terracotta)
                    .controlSize(.large)

                    // 支线
                    if !children.isEmpty {
                        SectionHeader(title: "由此开出的支线（\(children.count)）")
                        ForEach(children) { c in
                            NavigationLink(value: c.id) {
                                HStack(spacing: 10) {
                                    Image(systemName: "arrow.triangle.branch").foregroundStyle(Theme.terracotta)
                                    VStack(alignment: .leading) {
                                        Text(c.title).font(Theme.serif(15)).foregroundStyle(Theme.ink)
                                        Text(c.author).font(.caption2).foregroundStyle(Theme.inkSoft)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.line)
                                }
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                            }
                            .buttonStyle(.plain)
                        }
                    }

                    // 目录
                    SectionHeader(title: "目录 · \(book.chapters.count) 章")
                    VStack(spacing: 0) {
                        ForEach(Array(book.chapters.enumerated()), id: \.element.id) { idx, ch in
                            NavigationLink {
                                ReaderView(book: book, startIndex: ch.index)
                            } label: {
                                HStack {
                                    Text(ch.title).font(.subheadline).foregroundStyle(Theme.ink)
                                    Spacer()
                                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(Theme.line)
                                }
                                .padding(.vertical, 12)
                            }
                            if idx < book.chapters.count - 1 {
                                Divider().background(Theme.line)
                            }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                }
                .padding(20)
            }
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFork) {
            ForkComposerView(parent: book).environmentObject(store)
        }
    }
}
