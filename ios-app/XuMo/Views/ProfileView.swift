import SwiftUI

/// 我的：头像 + 统计块 + 菜单（我的书评 / 阅读历史 / 我的创作 / 设置）
struct ProfileView: View {
    @EnvironmentObject var store: LibraryStore

    var body: some View {
        ZStack {
            ScreenBackground(opacity: 0.5)
            ScrollView {
                VStack(spacing: 18) {
                    // 头像 + 名字
                    VStack(spacing: 8) {
                        Circle().fill(Theme.terracotta)
                            .frame(width: 84, height: 84)
                            .overlay(Text(String(MockData.profileName.prefix(1)))
                                .font(Theme.serif(34, .bold)).foregroundStyle(.white))
                        Text(MockData.profileName).font(Theme.serif(20, .bold)).foregroundStyle(Theme.ink)
                        Text(MockData.profileBio).font(.caption).foregroundStyle(Theme.sub)
                    }
                    .padding(.top, 8)

                    // 统计块
                    HStack {
                        ForEach(Array(MockData.profileStats.enumerated()), id: \.offset) { _, s in
                            VStack(spacing: 3) {
                                Text(s.0).font(Theme.serif(19, .bold)).foregroundStyle(Theme.ink)
                                Text(s.1).font(.caption2).foregroundStyle(Theme.sub)
                            }.frame(maxWidth: .infinity)
                        }
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14).fill(Theme.surface))
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Theme.line, lineWidth: 1))

                    // 菜单
                    VStack(spacing: 9) {
                        ForEach(MockData.profileMenu, id: \.self) { item in
                            if item == "我的创作" {
                                NavigationLink { MyCreationsList() } label: { MenuRow(title: item) }
                                    .buttonStyle(.plain)
                            } else {
                                MenuRow(title: item)
                            }
                        }
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("我的")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct MenuRow: View {
    let title: String
    var body: some View {
        HStack {
            Image(systemName: "leaf").font(.caption).foregroundStyle(Theme.olive)
            Text(title).font(.subheadline).foregroundStyle(Theme.ink)
            Spacer()
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
