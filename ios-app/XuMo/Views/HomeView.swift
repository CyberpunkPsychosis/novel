import SwiftUI

/// 首页：搜索 + 精选故事 + 本周必读 + 继续阅读
struct HomeView: View {
    @EnvironmentObject var store: LibraryStore
    private var featured: Book? { store.book(id: "huisheng") ?? store.books.first }
    private var weekly: [Book] { store.books.filter { !$0.isUserCreated && $0.id != featured?.id } }
    private var reading: [Book] { store.inProgressBooks }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    SearchBarStub(title: "书艺之阁")

                    if let featured {
                        SectionHeader(title: "精选故事", showAll: true)
                        NavigationLink(value: featured.id) {
                            FeaturedCardView(book: featured, rating: MockData.rating(featured.id))
                        }.buttonStyle(.plain)
                    }

                    SectionHeader(title: "本周必读", showAll: true)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(weekly) { b in
                                NavigationLink(value: b.id) {
                                    GridCoverCard(book: b, width: 100, rating: MockData.rating(b.id))
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 2)
                    }

                    if !reading.isEmpty {
                        SectionHeader(title: "继续阅读")
                        ForEach(reading) { b in
                            NavigationLink {
                                ReaderView(book: b, startIndex: store.lastReadIndex(b.id) ?? (b.chapters.first?.index ?? 1))
                            } label: {
                                ProgressRowView(book: b, fraction: store.fraction(for: b), caption: store.caption(for: b))
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("首页")
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
    }
}

/// 顶部"搜索栏"占位（原型不做真实搜索）
struct SearchBarStub: View {
    let title: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(Theme.sub)
            Text(title).font(Theme.serif(16, .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            Image(systemName: "bell").foregroundStyle(Theme.sub)
        }
        .padding(.horizontal, 16).padding(.vertical, 11)
        .background(Theme.surface.opacity(0.95))
        .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
        .clipShape(Capsule())
    }
}
