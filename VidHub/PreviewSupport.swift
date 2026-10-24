import SwiftUI

/// 命令行传入 `--preview home|browse|search|detail|player|me` 时直接渲染对应界面，
/// 用于在模拟器里截图检查版式。Release 包里 screen 恒为 nil。
enum PreviewMode {
    static var screen: String? {
        #if DEBUG
        let args = CommandLine.arguments
        guard let idx = args.firstIndex(of: "--preview"), idx + 1 < args.count else { return nil }
        return args[idx + 1]
        #else
        return nil
        #endif
    }
}

struct PreviewHost: View {
    let screen: String
    @EnvironmentObject private var model: AppModel

    var body: some View {
        Group {
            switch screen {
            case "browse":
                BrowseView()
            case "search":
                SearchView()
                    .onAppear {
                        model.searchText = "雾"
                        Task { await model.runSearch() }
                    }
            case "detail":
                NavigationStack {
                    DetailView(item: DemoData.all[5])
                }
            case "player":
                PlayerView(target: PlayerTarget(item: DemoData.all[0], lineIndex: 0, episodeIndex: 0))
            case "me":
                MeView()
            case "root":
                RootTabView()
            default:
                HomeView()
            }
        }
    }
}
