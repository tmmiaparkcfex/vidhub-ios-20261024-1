import Foundation
import SwiftUI

@MainActor
final class AppModel: ObservableObject {
    @Published var sources: [MediaSource] = []
    @Published var activeSourceID: String = ""

    @Published var categories: [CMSCategory] = []
    @Published var rails: [Rail] = []
    @Published var isLoadingHome = false
    @Published var homeError: String?
    @Published var lastUpdated: Date?

    @Published var browseItems: [MediaItem] = []
    @Published var browseLoading = false
    @Published var browseHasMore = true
    @Published var browseError: String?
    private var browsePage = 0
    private var browseTypeId: String?
    private var browseToken = UUID()

    @Published var searchText = ""
    @Published var searchHits: [SearchHit] = []
    @Published var searching = false
    @Published var searchError: String?
    private var searchToken = UUID()

    private let sourcesKey = "vidhub.sources.v2"
    private let defaults = UserDefaults.standard

    init() {
        loadSources()
    }

    // MARK: - 源

    var activeSource: MediaSource? {
        sources.first { $0.id == activeSourceID } ?? sources.first { $0.enabled }
    }

    var enabledSources: [MediaSource] { sources.filter { $0.enabled } }

    func sourceName(for id: String) -> String {
        sources.first { $0.id == id }?.name ?? "未知源"
    }

    func api(for sourceId: String) -> String? {
        sources.first { $0.id == sourceId }?.api
    }

    private func loadSources() {
        if let data = defaults.data(forKey: sourcesKey),
           let list = try? JSONDecoder().decode([MediaSource].self, from: data),
           !list.isEmpty {
            sources = list
        } else {
            sources = [MediaSource(id: DemoData.sourceId, name: "演示源", api: "demo://local", enabled: true, isDemo: true)]
        }
        if activeSourceID.isEmpty || !sources.contains(where: { $0.id == activeSourceID }) {
            activeSourceID = sources.first(where: { $0.enabled })?.id ?? sources.first?.id ?? ""
        }
    }

    private func saveSources() {
        if let data = try? JSONEncoder().encode(sources) {
            defaults.set(data, forKey: sourcesKey)
        }
    }

    func setActive(_ id: String) {
        activeSourceID = id
        rails = []
        categories = []
        Task { await loadHome() }
    }

    func addSources(_ list: [MediaSource]) {
        for s in list where !sources.contains(where: { $0.api == s.api }) {
            sources.append(s)
        }
        saveSources()
    }

    func addSource(name: String, api: String) {
        addSources([MediaSource(name: name.isEmpty ? "新接口" : name, api: api)])
        if activeSourceID.isEmpty { activeSourceID = sources.first?.id ?? "" }
    }

    func deleteSource(_ id: String) {
        sources.removeAll { $0.id == id }
        if activeSourceID == id { activeSourceID = sources.first?.id ?? "" }
        saveSources()
        Task { await loadHome() }
    }

    func toggleSource(_ id: String) {
        guard let idx = sources.firstIndex(where: { $0.id == id }) else { return }
        sources[idx].enabled.toggle()
        saveSources()
    }

    // MARK: - 首页

    func loadHome() async {
        guard let src = activeSource else { return }
        if isLoadingHome { return }
        isLoadingHome = true
        homeError = nil
        defer { isLoadingHome = false }

        if src.isDemo {
            categories = DemoData.categories
            var out: [Rail] = []
            out.append(Rail(id: "latest", title: "最近更新", items: DemoData.items(typeId: nil, page: 1, pageSize: 18).items))
            out.append(Rail(id: "top", title: "高分推荐",
                            items: Array(DemoData.all.sorted { $0.scoreValue > $1.scoreValue }.prefix(10))))
            for c in DemoData.categories.prefix(4) {
                out.append(Rail(id: "cat-\(c.id)", title: c.name,
                                items: DemoData.items(typeId: c.id, page: 1, pageSize: 12).items))
            }
            rails = out
            lastUpdated = Date()
            return
        }

        do {
            let res = try await CMSClient.shared.list(src.api, sourceId: src.id, typeId: nil, page: 1, keyword: nil)
            var cats = res.categories
            if cats.isEmpty { cats = (try? await CMSClient.shared.categories(src.api)) ?? [] }
            categories = cats

            var out: [Rail] = []
            if !res.items.isEmpty {
                out.append(Rail(id: "latest", title: "最近更新", items: res.items))
                out.append(Rail(id: "top", title: "高分推荐",
                                items: Array(res.items.sorted { $0.scoreValue > $1.scoreValue }.prefix(12))))
            }

            let picks = Array(cats.prefix(4))
            if !picks.isEmpty {
                let railResults = await withTaskGroup(of: (Int, Rail?).self) { group -> [(Int, Rail?)] in
                    for (i, c) in picks.enumerated() {
                        group.addTask {
                            let r = try? await CMSClient.shared.list(src.api, sourceId: src.id,
                                                                    typeId: c.id, page: 1, keyword: nil)
                            guard let r = r, !r.items.isEmpty else { return (i, nil) }
                            return (i, Rail(id: "cat-\(c.id)", title: c.name, items: Array(r.items.prefix(12))))
                        }
                    }
                    var buf: [(Int, Rail?)] = []
                    for await item in group { buf.append(item) }
                    return buf.sorted { $0.0 < $1.0 }
                }
                for (_, rail) in railResults { if let rail = rail { out.append(rail) } }
            }

            rails = out
            lastUpdated = Date()
            if out.isEmpty { homeError = "接口没有返回内容" }
        } catch {
            homeError = error.localizedDescription
        }
    }

    // MARK: - 分类浏览

    func resetBrowse(typeId: String?) async {
        browseToken = UUID()
        browseTypeId = typeId
        browsePage = 0
        browseItems = []
        browseHasMore = true
        browseError = nil
        await loadMoreBrowse()
    }

    func loadMoreBrowse() async {
        guard let src = activeSource else { return }
        guard browseHasMore, !browseLoading else { return }
        let token = browseToken
        browseLoading = true
        defer { browseLoading = false }
        let next = browsePage + 1

        if src.isDemo {
            let page = DemoData.items(typeId: browseTypeId, page: next, pageSize: 18)
            if token != browseToken { return }
            browseItems += page.items
            browseHasMore = page.hasMore
            browsePage = next
            return
        }

        do {
            let res = try await CMSClient.shared.list(src.api, sourceId: src.id,
                                                      typeId: browseTypeId, page: next, keyword: nil)
            if token != browseToken { return }
            let existing = Set(browseItems.map { $0.uid })
            browseItems += res.items.filter { !existing.contains($0.uid) }
            browsePage = next
            browseHasMore = next < res.pageCount && !res.items.isEmpty
        } catch {
            if token == browseToken { browseError = error.localizedDescription }
        }
    }

    // MARK: - 搜索

    func runSearch() async {
        let kw = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !kw.isEmpty else {
            searchHits = []
            return
        }
        searchToken = UUID()
        let token = searchToken
        searching = true
        searchError = nil
        defer { if token == searchToken { searching = false } }

        var hits: [SearchHit] = []
        for src in enabledSources {
            if src.isDemo {
                hits += DemoData.search(kw).map { SearchHit(item: $0, sourceName: src.name) }
                continue
            }
            if let res = try? await CMSClient.shared.list(src.api, sourceId: src.id, typeId: nil, page: 1, keyword: kw) {
                hits += res.items.map { SearchHit(item: $0, sourceName: src.name) }
            }
        }
        if token != searchToken { return }

        // 同名合并，保留条数最多的源
        var merged: [String: SearchHit] = [:]
        var order: [String] = []
        for hit in hits {
            let key = hit.item.name.trimmingCharacters(in: .whitespaces) + "|" + hit.item.year
            if var existed = merged[key] {
                existed.sourceCount += 1
                merged[key] = existed
            } else {
                merged[key] = hit
                order.append(key)
            }
        }
        let result = order.compactMap { merged[$0] }
        searchHits = result
        if result.isEmpty { searchError = "没有找到「\(kw)」" }
    }

    // MARK: - 详情

    func fetchDetail(_ item: MediaItem) async -> MediaItem {
        guard let src = sources.first(where: { $0.id == item.sourceId }) else { return item }
        if src.isDemo {
            return DemoData.item(id: item.id) ?? item
        }
        if item.playable { return item }
        if let full = try? await CMSClient.shared.detail(src.api, sourceId: src.id, id: item.id) {
            return full
        }
        return item
    }
}
