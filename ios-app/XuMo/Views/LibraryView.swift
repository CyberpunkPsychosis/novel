import SwiftUI

/// 发现页：精选大卡 + 本周必读横滑 + 书架网格（书艺之阁风）。
struct LibraryView: View {
    @EnvironmentObject var store: LibraryStore
    private let columns = [GridItem(.adaptive(minimum: 140), spacing: 18)]

    private var books: [Book] { store.seedAndPublished }
    private var featured: Book? { books.first }
    private var weekly: [Book] { Array(books.dropFirst().prefix(6)) }

    var body: some View {
        ZStack {
            // 真·首页背景：用作者拆出的植物线描素材（IMG_9479）
            Theme.bg.ignoresSafeArea()
            Image("HomeBackground")
                .resizable()
                .scaledToFill()
                .opacity(0.6)
                .ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    // 搜索栏
                    HStack(spacing: 8) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.inkSoft)
                        Text("搜书名、作者、标签…").foregroundStyle(Theme.inkSoft)
                        Spacer()
                    }
                    .font(.subheadline)
                    .padding(.horizontal, 14).padding(.vertical, 11)
                    .background(Theme.surface.opacity(0.92))
                    .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                    .clipShape(Capsule())

                    if let featured {
                        SectionHeader(title: "精选故事")
                        FeaturedCard(book: featured)
                    }

                    if !weekly.isEmpty {
                        SectionHeader(title: "本周必读")
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(alignment: .top, spacing: 16) {
                                ForEach(weekly) { book in
                                    NavigationLink(value: book.id) {
                                        CoverView(book: book)
                                            .frame(width: 120)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(.horizontal, 2)
                        }
                    }

                    SectionHeader(title: "书阁")
                    LazyVGrid(columns: columns, spacing: 22) {
                        ForEach(books) { book in
                            NavigationLink(value: book.id) {
                                BookCard(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("书艺之阁")
        .navigationDestination(for: String.self) { id in
            if let b = store.book(id: id) { BookDetailView(book: b) }
        }
    }
}

/// 精选大卡：鼠尾草绿底，左文右封。
struct FeaturedCard: View {
    let book: Book
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 10) {
                Text(book.title)
                    .font(Theme.serif(24, .bold))
                    .foregroundStyle(Theme.surface)
                Text(book.tagline.isEmpty ? String(book.blurb.prefix(36)) : book.tagline)
                    .font(.subheadline)
                    .foregroundStyle(Theme.surface.opacity(0.85))
                    .lineLimit(3)
                Text("立即阅读")
                    .font(.caption.bold())
                    .foregroundStyle(Theme.sage)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.surface)
                    .clipShape(Capsule())
            }
            Spacer(minLength: 8)
            CoverView(book: book).frame(width: 96)
        }
        .padding(18)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Theme.sage)
                .overlay(
                    Image(systemName: "leaf")
                        .font(.system(size: 90))
                        .foregroundStyle(Theme.surface.opacity(0.06))
                        .rotationEffect(.degrees(-18))
                        .offset(x: 110, y: 30),
                    alignment: .topTrailing
                )
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
    }
}

struct BookCard: View {
    @EnvironmentObject var store: LibraryStore
    let book: Book
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            CoverView(book: book)
            Text(book.title)
                .font(Theme.serif(16, .semibold))
                .foregroundStyle(Theme.ink)
                .lineLimit(1)
            HStack(spacing: 6) {
                Text(book.author).font(.caption2).foregroundStyle(Theme.inkSoft)
                if book.forkOf != nil { TagChip(text: "改编", color: Theme.terracotta) }
                Spacer()
                let n = store.forkCount(of: book.id)
                if n > 0 {
                    Label("\(n)", systemImage: "arrow.triangle.branch")
                        .font(.caption2).foregroundStyle(Theme.inkSoft)
                }
            }
        }
    }
}

/// 我的创作页。
struct MyCreationsView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            if store.myCreations.isEmpty {
                VStack(spacing: 14) {
                    Image(systemName: "leaf")
                        .font(.system(size: 44))
                        .foregroundStyle(Theme.sage.opacity(0.7))
                    Text("还没有你的创作")
                        .font(Theme.serif(20, .semibold))
                        .foregroundStyle(Theme.ink)
                    Text("去「书阁」挑一本，点「改编 / 续写」，\n就能开出属于你的支线。")
                        .font(.subheadline)
                        .foregroundStyle(Theme.inkSoft)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                ScrollView {
                    VStack(spacing: 14) {
                        ForEach(store.myCreations) { book in
                            NavigationLink(value: book.id) {
                                MyCreationRow(book: book)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(20)
                }
            }
        }
        .navigationTitle("我的创作")
        .navigationDestination(for: String.self) { id in
            if let b = store.book(id: id) { BookDetailView(book: b) }
        }
    }
}

struct MyCreationRow: View {
    let book: Book
    var body: some View {
        HStack(spacing: 14) {
            CoverView(book: book, showTitle: false).frame(width: 54)
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title).font(Theme.serif(17, .semibold)).foregroundStyle(Theme.ink)
                Text(book.tagline).font(.caption).foregroundStyle(Theme.inkSoft).lineLimit(1)
                Text("\(book.chapters.count) 章 · \(book.status)")
                    .font(.caption2).foregroundStyle(Theme.inkSoft)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.line)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}
