import SwiftUI

/// 社区中心：热门话题 + 书友俱乐部 + 最近活动（综合动态流）
struct CommunityView: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showCompose = false
    private let topicColors = ["#6E7042", "#B17D6B", "#A65A3C", "#7C4A38", "#1A2332"]

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
                    if store.topics.isEmpty {
                        Text("还没有话题，点「发布话题」开个头。")
                            .font(.footnote).foregroundStyle(Theme.sub)
                    } else {
                        ForEach(Array(store.topics.enumerated()), id: \.element.id) { i, t in
                            NavigationLink {
                                TopicDetailView(topicID: t.id, title: t.title)
                            } label: {
                                CategoryBanner(text: t.title, count: t.replyCount,
                                               color: Color(hex: topicColors[i % topicColors.count]))
                            }.buttonStyle(.plain)
                        }
                    }

                    SectionHeader(title: "书友俱乐部")
                    HStack(spacing: 12) {
                        ForEach(store.clubs) { c in
                            NavigationLink { ClubDetailView(clubID: c.id) } label: { ClubCard(club: c) }
                                .buttonStyle(.plain)
                        }
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
            .refreshable { await store.loadFeed(); await store.loadTopics(); await store.loadClubs() }
        }
        .navigationTitle("社区")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadFeed(); await store.loadTopics(); await store.loadClubs() }
        .sheet(isPresented: $showCompose) {
            CommunityComposeSheet { title in
                Task { await store.postTopic(title: title, body: "") }
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
    let club: ClubItem
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: "leaf").foregroundStyle(Theme.olive)
            Text(club.name).font(Theme.serif(14, .semibold)).foregroundStyle(Theme.ink)
            Text("\(club.memberCount) 成员").font(.caption2).foregroundStyle(Theme.sub)
            Text(club.joinedByMe ? "已加入" : "查看")
                .font(.caption2).foregroundStyle(club.joinedByMe ? Theme.olive : Theme.sub)
        }
        .frame(maxWidth: .infinity)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

/// 俱乐部详情：简介 + 加入/退出 + 成员 + 讨论区
struct ClubDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let clubID: String
    @State private var detail: ClubDetail?
    @State private var topics: [TopicItem] = []
    @State private var showCompose = false

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if let d = detail {
                        Text(d.name).font(Theme.serif(22, .bold)).foregroundStyle(Theme.ink)
                        if !d.intro.isEmpty {
                            Text(d.intro).font(.subheadline).foregroundStyle(Theme.sub)
                        }
                        Button {
                            store.toggleClub(clubID)
                            Task { detail = await store.clubDetail(clubID) }
                        } label: {
                            Text(d.joinedByMe ? "退出俱乐部" : "加入俱乐部")
                                .font(.subheadline.weight(.bold))
                                .foregroundStyle(d.joinedByMe ? Theme.sub : .white)
                                .frame(maxWidth: .infinity).padding(.vertical, 11)
                                .background(d.joinedByMe ? Theme.line.opacity(0.5) : Theme.terraDeep)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)

                        SectionHeader(title: "成员 \(d.memberCount)")
                        if d.members.isEmpty {
                            Text("还没有成员，第一个加入吧。").font(.caption).foregroundStyle(Theme.sub)
                        } else {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 14) {
                                    ForEach(Array(d.members.enumerated()), id: \.offset) { _, m in
                                        VStack(spacing: 4) {
                                            AvatarView(url: m.avatarUrl, colorHex: m.avatarColorHex, name: m.penName, size: 44)
                                            Text(m.penName).font(.caption2).foregroundStyle(Theme.sub).lineLimit(1)
                                        }.frame(width: 56)
                                    }
                                }
                            }
                        }
                    } else {
                        ProgressView().padding(.top, 40)
                    }

                    HStack {
                        SectionHeader(title: "讨论")
                        Spacer()
                        Button { showCompose = true } label: {
                            Label("发讨论", systemImage: "plus").font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.terraDeep)
                        }
                    }
                    if topics.isEmpty {
                        Text("还没有讨论，开个头吧。").font(.footnote).foregroundStyle(Theme.sub)
                    } else {
                        ForEach(topics) { t in
                            NavigationLink { TopicDetailView(topicID: t.id, title: t.title) } label: {
                                CategoryBanner(text: t.title, count: t.replyCount, color: Theme.olive)
                            }.buttonStyle(.plain)
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("俱乐部")
        .navigationBarTitleDisplayMode(.inline)
        .task { await reload() }
        .sheet(isPresented: $showCompose) {
            CommunityComposeSheet { title in
                Task { await store.postClubTopic(clubID, title: title, body: ""); topics = await store.clubTopics(clubID) }
            }
        }
    }

    private func reload() async {
        detail = await store.clubDetail(clubID)
        topics = await store.clubTopics(clubID)
    }
}

/// 话题详情：标题/正文 + 回帖列表 + 回帖框。
struct TopicDetailView: View {
    @EnvironmentObject var store: LibraryStore
    let topicID: String
    let title: String
    @State private var detail: TopicDetail?
    @State private var draft = ""
    @State private var sending = false

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(detail?.title ?? title).font(Theme.serif(20, .bold)).foregroundStyle(Theme.ink)
                        if let d = detail {
                            if !d.body.isEmpty {
                                Text(d.body).font(.body).foregroundStyle(Theme.ink.opacity(0.85)).lineSpacing(4)
                            }
                            Text("\(d.author) · \(d.replies.count) 回帖").font(.caption2).foregroundStyle(Theme.sub)
                            Divider().background(Theme.line)
                            if d.replies.isEmpty {
                                Text("还没有回帖，来说第一句。").font(.subheadline).foregroundStyle(Theme.sub)
                            } else {
                                ForEach(d.replies) { r in replyRow(r) }
                            }
                        } else {
                            ProgressView().padding(.top, 40)
                        }
                    }
                    .padding(20)
                }
                // 回帖框
                HStack(spacing: 10) {
                    TextField("写回帖…", text: $draft, axis: .vertical)
                        .lineLimit(1...4).padding(10)
                        .background(Theme.surface)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Theme.line, lineWidth: 1))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    Button { send() } label: {
                        Image(systemName: "paperplane.fill").foregroundStyle(.white)
                            .padding(10).background(Theme.terraDeep).clipShape(Circle())
                    }
                    .disabled(sending || draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)
                .background(Theme.cream)
            }
        }
        .navigationTitle("话题")
        .navigationBarTitleDisplayMode(.inline)
        .task { detail = await store.topicDetail(topicID) }
    }

    @ViewBuilder private func replyRow(_ r: TopicReplyItem) -> some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: r.avatarUrl, colorHex: r.avatarColorHex, name: r.author, size: 30)
            VStack(alignment: .leading, spacing: 3) {
                Text(r.author).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.ink)
                Text(r.text).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 8)
    }

    private func send() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        sending = true
        Task { @MainActor in
            if let r = await store.postReply(topicID: topicID, text: text) {
                detail?.replies.append(r)
                draft = ""
            }
            sending = false
        }
    }
}

struct FeedRow: View {
    let event: CommunityEvent
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarView(url: event.avatarUrl, colorHex: event.avatarColorHex, name: event.who, size: 34)
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
