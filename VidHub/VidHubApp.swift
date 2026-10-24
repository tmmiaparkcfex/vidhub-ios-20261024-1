import SwiftUI
import UIKit

@main
struct VidHubApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var model = AppModel()
    @StateObject private var library = LibraryStore()

    var body: some Scene {
        WindowGroup {
            Group {
                if let screen = PreviewMode.screen {
                    PreviewHost(screen: screen)
                } else {
                    RootTabView()
                }
            }
            .environmentObject(model)
            .environmentObject(library)
            .preferredColorScheme(.dark)
            .tint(Theme.accent)
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication,
                     supportedInterfaceOrientationsFor window: UIWindow?) -> UIInterfaceOrientationMask {
        OrientationManager.shared.allowLandscape ? .allButUpsideDown : .portrait
    }

    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        let appearance = UITabBarAppearance()
        appearance.configureWithOpaqueBackground()
        appearance.backgroundColor = UIColor(red: 0.043, green: 0.035, blue: 0.063, alpha: 1)
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
        return true
    }
}

final class OrientationManager {
    static let shared = OrientationManager()
    var allowLandscape = false

    func lockPortrait() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        scene?.requestGeometryUpdate(.iOS(interfaceOrientations: .portrait))
    }
}

struct RootTabView: View {
    @State private var tab = 0

    var body: some View {
        TabView(selection: $tab) {
            HomeView()
                .tabItem { Label("首页", systemImage: "house.fill") }
                .tag(0)
            BrowseView()
                .tabItem { Label("分类", systemImage: "square.grid.2x2.fill") }
                .tag(1)
            SearchView()
                .tabItem { Label("搜索", systemImage: "magnifyingglass") }
                .tag(2)
            MeView()
                .tabItem { Label("我的", systemImage: "person.fill") }
                .tag(3)
        }
        .tint(Theme.accent)
    }
}
