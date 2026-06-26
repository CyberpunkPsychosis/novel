import SwiftUI
import UIKit

/// 封面：优先用素材库里的真实封面（cover-<id>），没有则按配色生成复古书封。
struct CoverView: View {
    let book: Book
    var showTitle: Bool = true

    private var realCover: UIImage? { UIImage(named: "cover-\(book.id)") }
    private var colors: [Color] {
        let c = book.coverColors.isEmpty ? ["#B17D6B", "#8A3F28"] : book.coverColors
        return c.map { Color(hex: $0) }
    }
    private var accent: Color { Color(hex: book.coverAccent) }

    var body: some View {
        Group {
            if let img = realCover {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                proceduralCover
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .shadow(color: Theme.ink.opacity(0.18), radius: 6, x: 0, y: 3)
    }

    private var proceduralCover: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            RoundedRectangle(cornerRadius: 2).strokeBorder(accent.opacity(0.55), lineWidth: 1).padding(7)
            if showTitle {
                VStack(spacing: 8) {
                    Spacer()
                    Text(book.title).font(Theme.serif(20, .bold)).foregroundStyle(.white)
                        .multilineTextAlignment(.center).shadow(color: .black.opacity(0.35), radius: 3)
                    Spacer()
                    Text(book.author).font(Theme.serif(10)).foregroundStyle(.white.opacity(0.8)).padding(.bottom, 10)
                }
                .padding(.horizontal, 8)
            }
        }
    }
}
