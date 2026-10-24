import Foundation

/// 收藏、历史、播放进度（本地持久化）
final class LibraryStore: ObservableObject {
    @Published private(set) var favorites: [MediaItem] = []
    @Published private(set) var history: [WatchRecord] = []

    private let favoritesKey = "vidhub.favorites.v1"
    private let historyKey = "vidhub.history.v1"
    private let defaults = UserDefaults.standard
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init() {
        if let data = defaults.data(forKey: favoritesKey),
           let items = try? decoder.decode([MediaItem].self, from: data) {
            favorites = items
        }
        if let data = defaults.data(forKey: historyKey),
           let items = try? decoder.decode([WatchRecord].self, from: data) {
            history = items.sorted { $0.updated > $1.updated }
        }
    }

    // MARK: - 收藏

    func isFavorite(_ item: MediaItem) -> Bool {
        favorites.contains { $0.uid == item.uid }
    }

    func toggleFavorite(_ item: MediaItem) {
        if let idx = favorites.firstIndex(where: { $0.uid == item.uid }) {
            favorites.remove(at: idx)
        } else {
            favorites.insert(item, at: 0)
        }
        persistFavorites()
    }

    // MARK: - 观看记录

    var continueWatching: [WatchRecord] {
        history.filter { !$0.isFinished && $0.position > 5 }
    }

    func latestRecord(for item: MediaItem) -> WatchRecord? {
        history.first { $0.uid == item.uid }
    }

    func resumePosition(item: MediaItem, lineIndex: Int, episodeIndex: Int) -> Double? {
        guard let r = history.first(where: {
            $0.uid == item.uid && $0.lineIndex == lineIndex && $0.episodeIndex == episodeIndex
        }) else { return nil }
        return r.position > 5 ? r.position : nil
    }

    func update(item: MediaItem, lineIndex: Int, episodeIndex: Int, position: Double, duration: Double) {
        guard position.isFinite, position >= 0 else { return }
        let record = WatchRecord(uid: item.uid,
                                 item: item,
                                 lineIndex: lineIndex,
                                 episodeIndex: episodeIndex,
                                 position: position,
                                 duration: duration.isFinite ? duration : 0,
                                 updated: Date())
        if let idx = history.firstIndex(where: { $0.uid == item.uid }) {
            // 不同集的进度分别保留在 item 内不现实，这里以最新一集为准
            history[idx] = record
        } else {
            history.insert(record, at: 0)
        }
        history.sort { $0.updated > $1.updated }
        if history.count > 120 { history = Array(history.prefix(120)) }
        persistHistory()
    }

    func remove(_ record: WatchRecord) {
        history.removeAll { $0.uid == record.uid }
        persistHistory()
    }

    func clearHistory() {
        history.removeAll()
        persistHistory()
    }

    // MARK: - 落盘

    private func persistFavorites() {
        if let data = try? encoder.encode(favorites) {
            defaults.set(data, forKey: favoritesKey)
        }
    }

    private func persistHistory() {
        if let data = try? encoder.encode(history) {
            defaults.set(data, forKey: historyKey)
        }
    }
}
