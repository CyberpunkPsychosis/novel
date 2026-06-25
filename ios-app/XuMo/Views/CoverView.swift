import SwiftUI

/// 用 book.json 里的配色程序化生成封面（和网站的 SVG 封面一个思路），
/// 原型阶段不必管理图片资源。以后可换成真实 cover 图。
struct CoverView: View {
    let book: Book
    var showTitle: Bool = true

    private var colors: [Color] {
        let c = book.coverColors.isEmpty ? ["#0e0b0a", "#241a17", "#3a2a22"] : book.coverColors
        return c.map { Color(hex: $0) }
    }
    private var accent: Color { Color(hex: book.coverAccent) }

    var body: some View {
        ZStack {
            LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)

            // 一道斜向的"金线"，呼应金缮意象 / 品牌色
            GeometryReader { geo in
                Path { p in
                    p.move(to: CGPoint(x: geo.size.width * 0.1, y: geo.size.height * 0.72))
                    p.addLine(to: CGPoint(x: geo.size.width * 0.92, y: geo.size.height * 0.5))
                }
                .stroke(accent.opacity(0.7), lineWidth: 1.5)
            }

            if showTitle {
                VStack(spacing: 8) {
                    Spacer()
                    Text(book.title)
                        .font(.system(size: 26, weight: .bold))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .shadow(radius: 4)
                    if !book.tagline.isEmpty {
                        Text(book.tagline)
                            .font(.caption2)
                            .foregroundStyle(accent)
                            .multilineTextAlignment(.center)
                    }
                    Spacer()
                    Text(book.author)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.bottom, 10)
                }
                .padding(.horizontal, 8)
            }
        }
        .aspectRatio(3.0/4.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
