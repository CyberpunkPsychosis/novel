import SwiftUI

/// 社区中心：热门话题 + 书友俱乐部 + 最近活动（综合动态流）
struct CommunityView: View {
    @EnvironmentObject var store: LibraryStore

    /// 真实改编/续写事件拼到动态流最前
    private var forkEvents: [CommunityEvent] {
        store.myCreations.reversed().map { b in
            let label = b.tagline.contains("续写") ? "续写" : "改编"
            return CommunityEvent(who: b.author, avatarColorHex: "#A65A3C",
                                  text: "\(label)了《\(parentTitle(b))》，开出新支线", meta: "刚刚 · ⤴ \(label)")
        }
    }
    private func parentTitle(_ b: Book) -> String { b.forkOf.flatMap { store.book(id: $0)?.title } ?? "" }
    private var feed: [CommunityEvent] { forkEvents + MockData.baseFeed }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        SectionHeader(title: "热门话题")
                        Spacer()
                        Label("发布话题", systemImage: "plus")
                            .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#F4ECDF"))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Theme.terracotta).clipShape(Capsule())
                    }
                    ForEach(MockData.hotTopics) { t in
                        CategoryBanner(text: t.title, count: t.count, color: Color(hex: t.colorHex))
                    }

                    SectionHeader(title: "书友俱乐部")
                    HStack(spacing: 12) {
                        ForEach(MockData.clubs) { c in ClubCard(club: c) }
                    }

                    SectionHeader(title: "最近活动")
                    VStack(spacing: 0) {
                        ForEach(feed) { e in
                            FeedRow(event: e)
                            if e.id != feed.last?.id { Divider().background(Theme.line) }
                        }
                    }
                    .padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
                }
                .padding(20)
            }
        }
        .navigationTitle("社区")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ClubCard: View {
    let club: BookClub
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf").foregroundStyle(Theme.olive)
            Text(club.name).font(Theme.serif(14, .semibold)).foregroundStyle(Theme.ink)
            Text(club.members).font(.caption2).foregroundStyle(Theme.sub)
            Text("加入").font(.caption2).foregroundStyle(.white)
                .padding(.horizontal, 12).padding(.vertical, 4)
                .background(Theme.terracotta).clipShape(Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

struct FeedRow: View {
    let event: CommunityEvent
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Circle().fill(Color(hex: event.avatarColorHex))
                .frame(width: 34, height: 34)
                .overlay(Text(String(event.who.prefix(1))).font(.caption).foregroundStyle(.white))
            VStack(alignment: .leading, spacing: 3) {
                (Text(event.who).font(.subheadline.weight(.semibold)) + Text(" " + event.text).font(.subheadline))
                    .foregroundStyle(Theme.ink)
                Text(event.meta).font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }
}
