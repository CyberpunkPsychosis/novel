import SwiftUI

/// 品牌启动闪屏：logo + 植物背景 + 标语 + 本期主推书。约 1.5 秒后由 RootContainer 淡出。
struct SplashView: View {
    @EnvironmentObject var store: LibraryStore
    private var featured: Book? { store.book(id: "huisheng") ?? store.books.first }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.85)
            VStack(spacing: 18) {
                Spacer()
                Image(systemName: "book")
                    .font(.system(size: 56, weight: .light))
                    .foregroundStyle(Theme.blue)
                Text("书艺之阁")
                    .font(Theme.serif(40, .bold))
                    .foregroundStyle(Theme.blue)
                    .tracking(6)
                Rectangle().fill(Theme.bronze).frame(width: 56, height: 2)
                Text("慢慢长大的书架")
                    .font(Theme.serif(14))
                    .foregroundStyle(Theme.olive)
                    .tracking(3)
                if let featured {
                    CoverView(book: featured, showTitle: false)
                        .frame(width: 150)
                        .padding(.top, 12)
                    Text("本期主推 · \(featured.title)")
                        .font(.caption).foregroundStyle(Theme.sub)
                }
                Spacer()
            }
            .padding(40)
        }
    }
}
