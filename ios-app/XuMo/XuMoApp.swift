import SwiftUI

@main
struct XuMoApp: App {
    @StateObject private var store = LibraryStore()

    init() { Theme.applyAppearance() }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.light)
                .tint(Theme.terracotta)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { LibraryView() }
                .tabItem { Label("书阁", systemImage: "books.vertical") }

            NavigationStack { MyCreationsView() }
                .tabItem { Label("我的创作", systemImage: "pencil.and.outline") }
        }
        .tint(Theme.terracotta)
    }
}
