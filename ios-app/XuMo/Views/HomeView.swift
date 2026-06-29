import SwiftUI

/// 首页：搜索 + 精选故事 + 本周必读 + 继续阅读
struct HomeView: View {
    @EnvironmentObject var store: LibraryStore
    private var featured: Book? { store.books.first { $0.featured } ?? store.books.first }
    private var weekly: [Book] { store.books.filter { !$0.isUserCreated && $0.id != featured?.id } }
    private var reading: [Book] { store.inProgressBooks }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HomeTopBar(title: "书艺之阁", unread: store.unreadCount)

                    if let featured {
                        SectionHeader(title: "精选故事", showAll: true, allBooks: store.books.filter { !$0.isUserCreated })
                        NavigationLink(value: featured.id) {
                            FeaturedCardView(book: featured, rating: featured.ratingAvg)
                        }.buttonStyle(.plain)
                    }

                    SectionHeader(title: "本周必读", showAll: true, allBooks: weekly)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(weekly) { b in
                                NavigationLink(value: b.id) {
                                    GridCoverCard(book: b, width: 100, rating: b.ratingAvg)
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

/// 顶部栏：可点的搜索入口 + 通知铃（带未读红点）
struct HomeTopBar: View {
    let title: String
    let unread: Int
    var body: some View {
        HStack(spacing: 10) {
            NavigationLink { SearchView() } label: {
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass").foregroundStyle(Theme.sub)
                    Text(title).font(Theme.serif(16, .semibold)).foregroundStyle(Theme.ink)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(Theme.surface.opacity(0.95))
                .overlay(Capsule().stroke(Theme.line, lineWidth: 1))
                .clipShape(Capsule())
            }.buttonStyle(.plain)

            NavigationLink { NotificationsView() } label: {
                Image(systemName: "bell").foregroundStyle(Theme.sub)
                    .padding(11)
                    .background(Theme.surface.opacity(0.95))
                    .overlay(Circle().stroke(Theme.line, lineWidth: 1))
                    .clipShape(Circle())
                    .overlay(alignment: .topTrailing) {
                        if unread > 0 {
                            Circle().fill(Theme.terraDeep).frame(width: 9, height: 9).offset(x: -2, y: 2)
                        }
                    }
            }.buttonStyle(.plain)
        }
    }
}
