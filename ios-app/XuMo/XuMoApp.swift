import SwiftUI

@main
struct XuMoApp: App {
    @StateObject private var store = LibraryStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    var body: some View {
        TabView {
            NavigationStack { LibraryView() }
                .tabItem { Label("发现", systemImage: "books.vertical") }

            NavigationStack { MyCreationsView() }
                .tabItem { Label("我的创作", systemImage: "pencil.and.outline") }
        }
        .tint(Color(hex: "#d9a441"))
    }
}
