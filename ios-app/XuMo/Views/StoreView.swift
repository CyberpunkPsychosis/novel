import SwiftUI

/// 书店：精辑推荐 + 新书上架 + 畅销榜单
struct StoreView: View {
    @EnvironmentObject var store: LibraryStore
    private var feature: Book? { store.book(id: "qianfu") ?? store.books.first }
    private var newArrivals: [Book] { store.books.filter { !$0.isUserCreated } }
    /// 综合热度榜（服务器）；未拉到时退回种子书。
    private var bestsellers: [Book] {
        store.rankedBooks.isEmpty ? store.books.filter { !$0.isUserCreated } : store.rankedBooks
    }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    if let feature {
                        SectionHeader(title: "精辑推荐")
                        NavigationLink(value: feature.id) {
                            FeaturedCardView(book: feature, background: Color(hex: "#7C4A38"),
                                             rating: feature.ratingAvg)
                        }.buttonStyle(.plain)
                    }

                    SectionHeader(title: "新书上架", showAll: true, allBooks: newArrivals)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(alignment: .top, spacing: 14) {
                            ForEach(newArrivals) { b in
                                NavigationLink(value: b.id) {
                                    CoverView(book: b).frame(width: 96)
                                }.buttonStyle(.plain)
                            }
                        }.padding(.horizontal, 2)
                    }

                    SectionHeader(title: "畅销榜单")
                    VStack(spacing: 0) {
                        ForEach(Array(bestsellers.enumerated()), id: \.element.id) { i, b in
                            NavigationLink(value: b.id) {
                                RankRow(rank: i + 1, book: b, rating: b.ratingAvg)
                            }.buttonStyle(.plain)
                            if i < bestsellers.count - 1 { Divider().background(Theme.line) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                }
                .padding(20)
            }
        }
        .navigationTitle("书店")
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
    }
}

struct RankRow: View {
    let rank: Int
    let book: Book
    let rating: Double
    var body: some View {
        HStack(spacing: 12) {
            Text("\(rank)").font(Theme.serif(20, .bold)).foregroundStyle(Theme.bronze).frame(width: 24)
            CoverView(book: book, showTitle: false).frame(width: 40)
            VStack(alignment: .leading, spacing: 3) {
                Text(book.title).font(Theme.serif(15, .semibold)).foregroundStyle(Theme.ink)
                Text(book.author).font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer()
            RatingStars(value: rating, size: 11)
        }
        .padding(.vertical, 9)
    }
}
