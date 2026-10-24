import SwiftUI

struct BrowseView: View {
    @EnvironmentObject private var model: AppModel
    @State private var selectedType: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                GeometryReader { geo in
                    let cardWidth = max(88, (geo.size.width - 32 - 24) / 3)

                    ScrollView {
                        VStack(alignment: .leading, spacing: 14) {
                            Text("分类")
                                .font(.system(size: 26, weight: .heavy, design: .rounded))
                                .foregroundColor(Theme.text)
                                .padding(.horizontal, 16)
                                .padding(.top, 6)

                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    Button {
                                        select(nil)
                                    } label: {
                                        CategoryChip(title: "全部", selected: selectedType == nil)
                                    }
                                    ForEach(model.categories) { cat in
                                        Button {
                                            select(cat.id)
                                        } label: {
                                            CategoryChip(title: cat.name, selected: selectedType == cat.id)
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3),
                                      spacing: 16) {
                                ForEach(model.browseItems) { item in
                                    NavigationLink(value: item) {
                                        MediaCard(item: item, width: cardWidth)
                                    }
                                    .buttonStyle(.plain)
                                    .onAppear {
                                        if item.uid == model.browseItems.last?.uid {
                                            Task { await model.loadMoreBrowse() }
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 16)

                            if model.browseLoading {
                                ProgressView()
                                    .tint(.white.opacity(0.4))
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            } else if !model.browseHasMore && !model.browseItems.isEmpty {
                                Text("没有更多了")
                                    .font(.system(size: 11))
                                    .foregroundColor(Theme.textFaint)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }

                            if let err = model.browseError, model.browseItems.isEmpty {
                                EmptyStateView(icon: "exclamationmark.triangle",
                                               title: "加载失败",
                                               message: err,
                                               actionTitle: "重试") {
                                    Task { await model.resetBrowse(typeId: selectedType) }
                                }
                            }
                        }
                        .padding(.bottom, 24)
                    }
                    .refreshable {
                        await model.resetBrowse(typeId: selectedType)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
            .task {
                if model.categories.isEmpty, let src = model.activeSource, !src.isDemo {
                    model.categories = (try? await CMSClient.shared.categories(src.api)) ?? []
                }
                if model.categories.isEmpty { model.categories = DemoData.categories }
                if model.browseItems.isEmpty { await model.resetBrowse(typeId: nil) }
            }
        }
    }

    private func select(_ id: String?) {
        guard selectedType != id else { return }
        selectedType = id
        Task { await model.resetBrowse(typeId: id) }
    }
}
