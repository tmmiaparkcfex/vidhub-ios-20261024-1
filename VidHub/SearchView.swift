import SwiftUI

struct SearchView: View {
    @EnvironmentObject private var model: AppModel
    @FocusState private var focused: Bool
    @State private var showSettings = false

    private let hints = ["雾港", "长夜", "档案", "黎明", "星轨", "深海"]

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                GeometryReader { geo in
                    let cardWidth = max(88, (geo.size.width - 32 - 24) / 3)

                    VStack(spacing: 12) {
                        searchBar

                        ScrollView {
                            VStack(alignment: .leading, spacing: 14) {
                                if model.searching {
                                    ProgressView().tint(.white.opacity(0.4))
                                        .frame(maxWidth: .infinity)
                                        .padding(.top, 40)
                                } else if model.searchHits.isEmpty {
                                    idleState
                                } else {
                                    HStack {
                                        Text("找到 \(model.searchHits.count) 个结果")
                                            .font(.system(size: 11.5, weight: .medium))
                                            .foregroundColor(Theme.textFaint)
                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)

                                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                                              spacing: 16) {
                                        ForEach(model.searchHits) { hit in
                                            NavigationLink(value: hit.item) {
                                                VStack(alignment: .leading, spacing: 4) {
                                                    MediaCard(item: hit.item, width: cardWidth)
                                                    HStack(spacing: 3) {
                                                        Image(systemName: "dot.radiowaves.left.and.right")
                                                            .font(.system(size: 7, weight: .bold))
                                                        Text(hit.sourceCount > 1 ? "\(hit.sourceName) +\(hit.sourceCount - 1)" : hit.sourceName)
                                                            .lineLimit(1)
                                                    }
                                                    .font(.system(size: 9, weight: .medium))
                                                    .foregroundColor(Theme.textFaint)
                                                    .padding(.leading, 1)
                                                }
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .padding(.horizontal, 16)
                                }
                            }
                            .padding(.bottom, 24)
                        }
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
            .sheet(isPresented: $showSettings) { MeView(asSheet: true) }
        }
    }

    private var searchBar: some View {
        VStack(spacing: 8) {
            HStack(spacing: 9) {
                HStack(spacing: 7) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(Theme.textFaint)
                    TextField("搜索片名、演员", text: $model.searchText)
                        .font(.system(size: 14))
                        .foregroundColor(Theme.text)
                        .focused($focused)
                        .submitLabel(.search)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .onSubmit { Task { await model.runSearch() } }
                    if !model.searchText.isEmpty {
                        Button {
                            model.searchText = ""
                            model.searchHits = []
                            model.searchError = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 13))
                                .foregroundColor(Theme.textFaint)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 0.8)
                )

                Button {
                    focused = false
                    Task { await model.runSearch() }
                } label: {
                    Text("搜索")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 13)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.9), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }

            HStack(spacing: 4) {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 8, weight: .bold))
                Text("在 \(model.enabledSources.count) 个源中同时搜索")
                    .font(.system(size: 10))
            }
            .foregroundColor(Theme.textFaint)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
    }

    private var idleState: some View {
        VStack(spacing: 18) {
            if let err = model.searchError {
                EmptyStateView(icon: "magnifyingglass", title: "没有结果", message: err,
                               actionTitle: model.enabledSources.count <= 1 ? "添加更多接口" : nil) {
                    showSettings = true
                }
            } else {
                EmptyStateView(icon: "magnifyingglass.circle.fill",
                               title: "搜点什么",
                               message: "输入片名，会同时在所有已启用的接口里找，同一部片子自动合并显示来源数。")
            }

            VStack(alignment: .leading, spacing: 9) {
                Text("试试这些")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Theme.textFaint)
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                    ForEach(hints, id: \.self) { hint in
                        Button {
                            model.searchText = hint
                            focused = false
                            Task { await model.runSearch() }
                        } label: {
                            Text(hint)
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .foregroundColor(Theme.textDim)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.05), in: Capsule())
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
    }
}
