import SwiftUI

@main
struct XuMoApp: App {
    @StateObject private var store = LibraryStore()
    init() { Theme.applyAppearance() }
    var body: some Scene {
        WindowGroup {
            RootContainer()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(Theme.terraDeep)
        }
    }
}

/// 启动闪屏 → 按登录态进 登录页 / 主界面
struct RootContainer: View {
    @EnvironmentObject var store: LibraryStore
    @State private var showSplash = true
    var body: some View {
        ZStack {
            if store.isLoggedIn {
                MainTabView()
            } else {
                AuthView()
            }
            if showSplash {
                SplashView().transition(.opacity)
            }
        }
        .task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            withAnimation(.easeInOut(duration: 0.5)) { showSplash = false }
        }
        // 已登录（含重装后 Keychain 仍在）时，冷启动拉一次云端书库与进度。
        .task(id: store.isLoggedIn) {
            guard store.isLoggedIn else { return }
            await store.refreshBooks()
            await store.loadRemoteProgress()
        }
    }
}

/// 底部 5 个 tab：首页 / 书店 / 书架 / 社区 / 我的
struct MainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { HomeView() }
                .tabItem { Label("首页", systemImage: "house") }
            NavigationStack { StoreView() }
                .tabItem { Label("书店", systemImage: "storefront") }
            NavigationStack { ShelfView() }
                .tabItem { Label("书架", systemImage: "books.vertical") }
            NavigationStack { CommunityView() }
                .tabItem { Label("社区", systemImage: "bubble.left.and.bubble.right") }
            NavigationStack { ProfileView() }
                .tabItem { Label("我的", systemImage: "person") }
        }
        .tint(Theme.terraDeep)
    }
}

/// 把书 id 推到书详情的通用目的地
extension View {
    func bookDestination(_ store: LibraryStore) -> some View {
        navigationDestination(for: String.self) { id in
            if let b = store.book(id: id) { BookDetailView(book: b) }
        }
    }
}
