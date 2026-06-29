import SwiftUI
import PhotosUI

/// 我的：头像 + 统计块 + 钱包入口 + 菜单
struct ProfileView: View {
    @EnvironmentObject var store: LibraryStore

    private var user: LocalUser { store.currentUser ?? LocalUser(id: "me", handle: "me", penName: "我") }
    private var stats: [(String, String)] {
        [("\(store.myCreations.count)", "创作"),
         ("\(store.myStats.reviews)", "书评"),
         ("\(store.myStats.likesReceived)", "获赞"),
         ("\(store.molDi)", "墨滴")]
    }

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(spacing: 18) {
                    // 头像 + 名字（点头像/名字进编辑）
                    NavigationLink { EditProfileView() } label: {
                        VStack(spacing: 8) {
                            AvatarView(url: user.avatarUrl, colorHex: user.avatarColorHex,
                                       name: user.penName, size: 84)
                            HStack(spacing: 5) {
                                Text(user.penName).font(Theme.serif(20, .bold)).foregroundStyle(Theme.ink)
                                Image(systemName: "pencil.circle").font(.caption).foregroundStyle(Theme.sub)
                            }
                            Text("@\(user.handle) · \(user.bio)").font(.caption).foregroundStyle(Theme.sub)
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 8)

                    // 统计块
                    HStack {
                        ForEach(Array(stats.enumerated()), id: \.offset) { _, s in
                            VStack(spacing: 3) {
                                Text(s.0).font(Theme.serif(19, .bold)).foregroundStyle(Theme.ink)
                                Text(s.1).font(.caption2).foregroundStyle(Theme.sub)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                    // 钱包入口
                    NavigationLink { WalletView() } label: { WalletCard(molDi: store.molDi, canCheckin: store.canCheckinToday) }
                        .buttonStyle(.plain)

                    // 菜单
                    VStack(spacing: 9) {
                        NavigationLink { MyCreationsList() } label: { MenuRow(title: "我的创作", icon: "books.vertical") }
                            .buttonStyle(.plain)
                        NavigationLink { MyReviewsList() } label: { MenuRow(title: "我的书评", icon: "text.bubble") }
                            .buttonStyle(.plain)
                        NavigationLink { ForkRequestsInboxView() } label: {
                            MenuRow(title: "改编申请", icon: "arrow.triangle.branch",
                                    badge: store.incomingForkRequests.filter { $0.status == .pending }.count)
                        }.buttonStyle(.plain)
                        NavigationLink { ReadingHistoryView() } label: { MenuRow(title: "阅读历史", icon: "clock") }
                            .buttonStyle(.plain)
                        NavigationLink { SettingsView() } label: { MenuRow(title: "设置", icon: "gearshape") }
                            .buttonStyle(.plain)
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
        .task { await store.loadMyStats() }
    }
}

/// 编辑资料：头像（相册上传）+ 笔名 + 简介 + 头像底色
struct EditProfileView: View {
    @EnvironmentObject var store: LibraryStore
    @Environment(\.dismiss) private var dismiss
    @State private var penName = ""
    @State private var bio = ""
    @State private var colorHex = "#A65A3C"
    @State private var pickerItem: PhotosPickerItem?
    @State private var busy = false

    private let palette = ["#A65A3C", "#B17D6B", "#6E7042", "#7C4A38", "#1A2332", "#C7A17A"]

    var body: some View {
        ZStack {
            Theme.cream.ignoresSafeArea()
            Form {
                Section {
                    HStack {
                        Spacer()
                        VStack(spacing: 10) {
                            AvatarView(url: store.currentUser?.avatarUrl, colorHex: colorHex,
                                       name: penName.isEmpty ? "我" : penName, size: 88)
                            PhotosPicker(selection: $pickerItem, matching: .images) {
                                Text(busy ? "上传中…" : "更换头像").font(.caption.weight(.semibold))
                                    .foregroundStyle(Theme.terraDeep)
                            }.disabled(busy)
                        }
                        Spacer()
                    }
                }
                .listRowBackground(Color.clear)

                Section("笔名") {
                    TextField("笔名", text: $penName)
                }.listRowBackground(Theme.surface)

                Section("简介") {
                    TextField("一句话简介", text: $bio, axis: .vertical).lineLimit(2...4)
                }.listRowBackground(Theme.surface)

                Section("头像底色（无照片时显示）") {
                    HStack(spacing: 12) {
                        ForEach(palette, id: \.self) { hex in
                            Circle().fill(Color(hex: hex)).frame(width: 30, height: 30)
                                .overlay(Circle().stroke(Theme.ink, lineWidth: colorHex == hex ? 2 : 0))
                                .onTapGesture { colorHex = hex }
                        }
                    }
                }.listRowBackground(Theme.surface)
            }
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("编辑资料")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("保存") {
                    Task { @MainActor in
                        await store.updateProfile(penName: penName, bio: bio, avatarColorHex: colorHex)
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            penName = store.currentUser?.penName ?? ""
            bio = store.currentUser?.bio ?? ""
            colorHex = store.currentUser?.avatarColorHex ?? "#A65A3C"
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task { @MainActor in
                busy = true
                if let data = try? await item.loadTransferable(type: Data.self) {
                    await store.uploadAvatar(data)
                }
                busy = false
            }
        }
    }
}

/// 「我的书评」列表
struct MyReviewsList: View {
    @EnvironmentObject var store: LibraryStore
    @State private var reviews: [BookReview] = []
    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(spacing: 12) {
                    if reviews.isEmpty {
                        Text("还没有书评。").font(.subheadline).foregroundStyle(Theme.sub).padding(.top, 40)
                    } else {
                        ForEach(reviews) { r in
                            NavigationLink(value: r.bookID) {
                                VStack(alignment: .leading, spacing: 5) {
                                    Text(store.book(id: r.bookID)?.title ?? "某书")
                                        .font(Theme.serif(15, .semibold)).foregroundStyle(Theme.ink)
                                    Text(r.text).font(.subheadline).foregroundStyle(Theme.ink.opacity(0.85))
                                    Text("♥ \(r.likeCount)").font(.caption2).foregroundStyle(Theme.terracotta)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(12)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Theme.surface))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
        }
        .navigationTitle("我的书评")
        .navigationBarTitleDisplayMode(.inline)
        .task { reviews = await store.myReviews() }
        .bookDestination(store)
    }
}

/// 钱包摘要卡
struct WalletCard: View {
    let molDi: Int
    let canCheckin: Bool
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "drop.fill").font(.title2).foregroundStyle(Theme.terracotta)
            VStack(alignment: .leading, spacing: 2) {
                Text("\(molDi) 墨滴").font(Theme.serif(19, .bold)).foregroundStyle(Theme.ink)
                Text(canCheckin ? "今日还没签到，点这里领墨滴" : "今日已签到").font(.caption2).foregroundStyle(Theme.sub)
            }
            Spacer()
            if canCheckin {
                Text("签到").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 12).padding(.vertical, 6)
                    .background(Theme.terraDeep).clipShape(Capsule())
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.line)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))
    }
}

/// 阅读历史（按本地进度）
struct ReadingHistoryView: View {
    @EnvironmentObject var store: LibraryStore
    private var history: [Book] { store.books.filter { store.readingProgress[$0.id] != nil } }
    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(spacing: 12) {
                    if history.isEmpty {
                        Text("还没有阅读记录。").font(.subheadline).foregroundStyle(Theme.sub).padding(.top, 40)
                    } else {
                        ForEach(history) { b in
                            NavigationLink {
                                ReaderView(book: b, startIndex: store.lastReadIndex(b.id) ?? 1)
                            } label: {
                                ProgressRowView(book: b, fraction: store.fraction(for: b), caption: store.caption(for: b))
                            }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
        }
        .navigationTitle("阅读历史")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MenuRow: View {
    let title: String
    var icon: String = "leaf"
    var badge: Int = 0
    var body: some View {
        HStack {
            Image(systemName: icon).font(.caption).foregroundStyle(Theme.olive).frame(width: 18)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
            if badge > 0 {
                Text("\(badge)").font(.caption2.weight(.bold)).foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Theme.terraDeep).clipShape(Capsule())
            }
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.line)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(Theme.surface))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.line, lineWidth: 1))
    }
}

/// 「我的创作」列表（从个人资料进入）
struct MyCreationsList: View {
    @EnvironmentObject var store: LibraryStore
    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(spacing: 12) {
                    if store.myCreations.isEmpty {
                        Text("还没有你的创作。").font(.subheadline).foregroundStyle(Theme.sub).padding(.top, 40)
                    } else {
                        ForEach(store.myCreations) { b in
                            NavigationLink(value: b.id) { CreationRow(book: b) }.buttonStyle(.plain)
                        }
                    }
                }.padding(20)
            }
        }
        .navigationTitle("我的创作")
        .navigationBarTitleDisplayMode(.inline)
        .bookDestination(store)
    }
}
