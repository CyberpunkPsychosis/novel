import SwiftUI

/// 复古书封：保留每本书自己的配色，做成"经典书籍封面"的样子
/// （衬线书名 + 双线内框 + 柔和投影），落在米纸底上更像一座真实书架。
struct CoverView: View {
    let book: Book
    var showTitle: Bool = true

    private var colors: [Color] {
        let c = book.coverColors.isEmpty ? ["#BE5A39", "#8A3F28"] : book.coverColors
        return c.map { Color(hex: $0) }
    }
    private var accent: Color { Color(hex: book.coverAccent) }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)

            // 经典书封的双线内框
            RoundedRectangle(cornerRadius: 2)
                .strokeBorder(accent.opacity(0.55), lineWidth: 1)
                .padding(7)

            if showTitle {
                VStack(spacing: 8) {
                    Spacer()
                    Text(book.title)
                        .font(Theme.serif(22, .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(color: .black.opacity(0.35), radius: 3)
                    if !book.tagline.isEmpty {
                        Text(book.tagline)
                            .font(Theme.serif(10))
                            .foregroundStyle(.white.opacity(0.85))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                    }
                    Spacer()
                    Text(book.author)
                        .font(Theme.serif(11))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.bottom, 12)
                }
                .padding(.horizontal, 10)
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, x: 0, y: 3)
    }
}
