import SwiftUI

/// 书架：在读（进度）+ 我的创作（改编/续写）+ 收藏
struct ShelfView: View {
    @EnvironmentObject var store: LibraryStore
    private let grid = [GridItem(.adaptive(minimum: 100), spacing: 16)]
    private var reading: [Book] { store.inProgressBooks }
    private var mine: [Book] { store.myCreations }
    private var favorites: [Book] { store.books.filter { !$0.isUserCreated } }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if !reading.isEmpty {
                        SectionHeader(title: "在读")
                        ForEach(reading) { b in
                            NavigationLink {
                                ReaderView(book: b, startIndex: store.lastReadIndex(b.id) ?? 1)
                            } label: {
                                ProgressRowView(book: b, fraction: store.fraction(for: b), caption: store.caption(for: b))
                            }.buttonStyle(.plain)
                        }
                    }

                    SectionHeader(title: "我的创作")
                    if mine.isEmpty {
                        Text("还没有你的创作。去任意一本书点「改编 / 续写」，就能开出属于你的支线。")
                            .font(.footnote).foregroundStyle(Theme.sub)
                            .padding(14)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                    } else {
                        ForEach(mine) { b in
                            NavigationLink(value: b.id) { CreationRow(book: b) }.buttonStyle(.plain)
                        }
                    }

                    SectionHeader(title: "收藏")
                    LazyVGrid(columns: grid, spacing: 18) {
                        ForEach(favorites) { b in
                            NavigationLink(value: b.id) { CoverView(book: b) }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("书架")
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
    }
}

struct CreationRow: View {
    let book: Book
    var body: some View {
        HStack(spacing: 12) {
            CoverView(book: book, showTitle: false).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title).font(Theme.serif(15, .semibold)).foregroundStyle(Theme.ink)
                TagChip(text: book.tagline, color: Theme.terraDeep)
                Text("\(book.chapters.count) 章 · \(book.status)").font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.line)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}
