import SwiftUI

/// 「查看全部」通用列表：网格展示一组书。
struct AllListView: View {
    @EnvironmentObject var store: LibraryStore
    let title: String
    let books: [Book]
    private let grid = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                LazyVGrid(columns: grid, spacing: 18) {
                    ForEach(books) { b in
                        NavigationLink(value: b.id) {
                            GridCoverCard(book: b, width: 100, rating: b.ratingAvg)
                        }.buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
    }
}
