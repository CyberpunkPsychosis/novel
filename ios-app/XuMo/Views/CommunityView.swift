import SwiftUI

/// 社区中心：热门话题 + 书友俱乐部 + 最近活动（综合动态流）
struct CommunityView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showCompose = false
    @State private var postedTopics: [HotTopic] = []

    /// 全站活动流（服务器真数据）；未拉到时退回演示数据。
    private var feed: [CommunityEvent] { store.feed.isEmpty ? MockData.baseFeed : store.feed }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    HStack {
                        SectionHeader(title: "热门话题")
                        Spacer()
                        Button { showCompose = true } label: {
                            Label("发布话题", systemImage: "plus")
                                .font(.caption.weight(.semibold)).foregroundStyle(Color(hex: "#F4ECDF"))
                                .padding(.horizontal, 12).padding(.vertical, 6)
                                .background(Theme.terracotta).clipShape(Capsule())
                        }.buttonStyle(.plain)
                    }
                    ForEach(postedTopics + MockData.hotTopics) { t in
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
        .task { await store.loadFeed() }
        .refreshable { await store.loadFeed() }
        .sheet(isPresented: $showCompose) {
            CommunityComposeSheet { title in
                postedTopics.insert(HotTopic(title: title.hasPrefix("#") ? title : "#\(title)",
                                             count: 1, colorHex: "#A65A3C"), at: 0)
                store.pushNotification(.system, text: "你发布了话题「\(title)」")
            }
        }
    }
}

/// 发布话题
struct CommunityComposeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let onPost: (String) -> Void
    @State private var text = ""
    var body: some View {
        NavigationStack {
            ZStack {
                Theme.cream.ignoresSafeArea()
                VStack(alignment: .leading, spacing: 12) {
                    Text("说点什么").font(Theme.serif(18, .semibold)).foregroundStyle(Theme.ink)
                    TextField("例：如果让你改写女主结局…", text: $text, axis: .vertical)
                        .lineLimit(3...6).padding(12)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    Spacer()
                }
                .padding(20)
            }
            .navigationTitle("发布话题")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("取消") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("发布") { onPost(text.trimmingCharacters(in: .whitespacesAndNewlines)); dismiss() }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
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
