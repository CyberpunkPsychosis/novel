import SwiftUI

struct BookDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book

    @State private var showFork = false

    private var parent: Book? { book.forkOf.flatMap { store.book(id: $0) } }
    private var children: [Book] { store.forks(of: book.id) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                // 头部：封面 + 基本信息
                HStack(alignment: .top, spacing: 16) {
                    CoverView(book: book).frame(width: 130)
                    VStack(alignment: .leading, spacing: 8) {
                        Text(book.title).font(.title2.bold())
                        Text(book.author).font(.subheadline).foregroundStyle(.secondary)
                        if !book.status.isEmpty {
                            Text(book.status).font(.caption)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(.gray.opacity(0.2)).clipShape(Capsule())
                        }
                        if let parent {
                            NavigationLink(value: parent.id) {
                                Label("改编自《\(parent.title)》", systemImage: "arrow.uturn.backward")
                                    .font(.caption)
                            }
                        }
                    }
                    Spacer()
                }

                // 标签
                if !book.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            ForEach(book.tags, id: \.self) { t in
                                Text(t).font(.caption)
                                    .padding(.horizontal, 10).padding(.vertical, 4)
                                    .background(Color(hex: book.coverAccent).opacity(0.18))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }

                // 简介
                Text(book.blurb).font(.body).foregroundStyle(.secondary)

                // 核心操作：改编 / 续写
                Button {
                    showFork = true
                } label: {
                    Label("改编 / 续写这本书", systemImage: "arrow.triangle.branch")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hex: book.coverAccent))
                .controlSize(.large)

                // 被改编的支线
                if !children.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("由此开出的支线（\(children.count)）")
                            .font(.headline)
                        ForEach(children) { c in
                            NavigationLink(value: c.id) {
                                HStack {
                                    Image(systemName: "arrow.triangle.branch")
                                        .foregroundStyle(Color(hex: book.coverAccent))
                                    VStack(alignment: .leading) {
                                        Text(c.title).font(.subheadline)
                                        Text(c.author).font(.caption2).foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    Image(systemName: "chevron.right")
                                        .font(.caption2).foregroundStyle(.tertiary)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Divider()

                // 目录
                Text("目录（\(book.chapters.count) 章）").font(.headline)
                ForEach(book.chapters) { ch in
                    NavigationLink {
                        ReaderView(book: book, startIndex: ch.index)
                    } label: {
                        HStack {
                            Text(ch.title).font(.subheadline).foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                        }
                        .padding(.vertical, 6)
                    }
                    Divider()
                }
            }
            .padding()
        }
        .navigationTitle(book.title)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFork) {
            ForkComposerView(parent: book)
                .environmentObject(store)
        }
    }
}
