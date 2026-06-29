import SwiftUI

/// 他人主页（只读）：头像 + 简介 + TA 的创作 + 书评数。
struct UserProfileView: View {
    @EnvironmentObject var store: LibraryStore
    let handle: String
    @State private var profile: UserProfile?
    private let grid = [GridItem(.adaptive(minimum: 100), spacing: 16)]

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                if let p = profile {
                    VStack(spacing: 16) {
                        AvatarView(url: p.avatarUrl, colorHex: p.avatarColorHex, name: p.penName, size: 84)
                        Text(p.penName).font(Theme.serif(20, .bold)).foregroundStyle(Theme.ink)
                        Text("@\(p.handle) · \(p.bio)").font(.caption).foregroundStyle(Theme.sub)
                        HStack {
                            stat("\(p.books.count)", "创作")
                            stat("\(p.reviewCount)", "书评")
                        }
                        .padding(14)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))

                        if !p.books.isEmpty {
                            HStack { SectionHeader(title: "TA 的创作"); Spacer() }
                            LazyVGrid(columns: grid, spacing: 18) {
                                ForEach(p.books) { b in
                                    NavigationLink(value: b.id) { CoverView(book: b) }.buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text("TA 还没有公开的创作。").font(.footnote).foregroundStyle(Theme.sub).padding(.top, 20)
                        }
                    }
                    .padding(20)
                } else {
                    ProgressView().padding(.top, 60)
                }
            }
        }
        .navigationTitle(profile?.penName ?? "主页")
        .navigationBarTitleDisplayMode(.inline)
        .task { profile = await store.userProfile(handle) }
        .bookDestination(store)
    }

    private func stat(_ v: String, _ label: String) -> some View {
        VStack(spacing: 3) {
            Text(v).font(Theme.serif(19, .bold)).foregroundStyle(Theme.ink)
            Text(label).font(.caption2).foregroundStyle(Theme.sub)
        }.frame(maxWidth: .infinity)
    }
}
