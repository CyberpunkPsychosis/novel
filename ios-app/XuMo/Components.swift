import SwiftUI

// MARK: 屏幕背景（作者提供的植物线描素材 IMG_9479）

struct ScreenBackground: View {
    var opacity: Double = 0.4
    var body: some View {
        // 用 Color 承载尺寸（柔性，跟随屏幕），背景图作为 overlay 且裁剪，
        // 避免横向大图把整屏宽度撑坏（之前排版错乱的根因）。
        Theme.cream
            .overlay {
                Image("HomeBackground")
                    .resizable()
                    .scaledToFill()
                    .opacity(opacity)
                    .clipped()
                    .allowsHitTesting(false)
            }
            .ignoresSafeArea()
    }
}

// MARK: 区块标题（叶子 + 衬线标题 + 可选「查看全部」）

struct SectionHeader: View {
    let title: String
    var showAll: Bool = false
    var body: some View {
        HStack(spacing: 7) {
            Image(systemName: "leaf").font(.caption).foregroundStyle(Theme.olive)
            Text(title).font(Theme.serif(19, .semibold)).foregroundStyle(Theme.ink)
            Spacer()
            if showAll {
                Text("查看全部 ›").font(.caption).foregroundStyle(Theme.terraDeep)
            }
        }
    }
}

// MARK: 标签胶囊

struct TagChip: View {
    let text: String
    var color: Color = Theme.olive
    var body: some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 10).padding(.vertical, 4)
            .background(color.opacity(0.14))
            .overlay(Capsule().stroke(color.opacity(0.3), lineWidth: 0.5))
            .clipShape(Capsule())
    }
}

// MARK: 星级评分

struct RatingStars: View {
    let value: Double          // 0...5
    var size: CGFloat = 12
    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { i in
                Image(systemName: symbol(for: i))
                    .font(.system(size: size))
                    .foregroundStyle(Theme.bronze)
            }
        }
    }
    private func symbol(for i: Int) -> String {
        let d = value - Double(i)
        if d >= 1 { return "star.fill" }
        if d >= 0.5 { return "star.leadinghalf.filled" }
        return "star"
    }
}

// MARK: 主按钮样式（实心 Bronze）

struct BronzeButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.ink)
            .padding(.horizontal, 14).padding(.vertical, 7)
            .background(Theme.bronze.opacity(configuration.isPressed ? 0.8 : 1))
            .clipShape(Capsule())
    }
}

// MARK: 继续阅读 / 在读 列表行

struct ProgressRowView: View {
    let book: Book
    let fraction: Double   // 0...1
    var caption: String? = nil
    var body: some View {
        HStack(spacing: 12) {
            CoverView(book: book, showTitle: false).frame(width: 42)
            VStack(alignment: .leading, spacing: 5) {
                Text(book.title).font(Theme.serif(15, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
                Text(caption ?? book.author).font(.caption2).foregroundStyle(Theme.sub)
                ProgressView(value: fraction)
                    .tint(Theme.bronze)
                    .scaleEffect(x: 1, y: 0.8, anchor: .center)
            }
            Text("\(Int(fraction * 100))%")
                .font(.caption.weight(.bold)).foregroundStyle(Theme.terraDeep)
                .frame(width: 40, alignment: .trailing)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

// MARK: 网格 / 横滑封面卡

struct GridCoverCard: View {
    let book: Book
    var width: CGFloat? = nil
    var rating: Double? = nil
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            CoverView(book: book).frame(width: width)
            Text(book.title).font(Theme.serif(14, .semibold)).foregroundStyle(Theme.ink).lineLimit(1)
            HStack(spacing: 5) {
                Text(book.author).font(.caption2).foregroundStyle(Theme.sub)
                if let rating { RatingStars(value: rating, size: 9) }
            }
        }
        .frame(width: width)
    }
}

// MARK: 精选大卡（Deep Blue 底）

struct FeaturedCardView: View {
    let book: Book
    var background: Color = Theme.blue
    var rating: Double = 4.5
    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(book.title).font(Theme.serif(21, .bold)).foregroundStyle(Color(hex: "#F4ECDF"))
                Text(book.tagline.isEmpty ? book.author : "\(book.author) · \(book.tagline)")
                    .font(.caption).foregroundStyle(Color(hex: "#F4ECDF").opacity(0.7)).lineLimit(2)
                RatingStars(value: rating)
                // 非交互的"立即阅读"标签（整卡作为导航链接）
                Label("立即阅读", systemImage: "play.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                    .padding(.horizontal, 14).padding(.vertical, 7)
                    .background(Theme.bronze)
                    .clipShape(Capsule())
                    .padding(.top, 4)
            }
            Spacer(minLength: 4)
            CoverView(book: book, showTitle: false).frame(width: 86)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16).fill(background))
    }
}

// MARK: 热门话题 异形横幅

struct CategoryBanner: View {
    let text: String
    let count: Int
    var color: Color = Theme.olive
    var body: some View {
        HStack {
            Text(text).font(.subheadline.weight(.semibold)).foregroundStyle(Color(hex: "#F4ECDF"))
            Spacer()
            Text("\(count) 讨论").font(.caption2).foregroundStyle(Color(hex: "#F4ECDF").opacity(0.8))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(color))
    }
}
