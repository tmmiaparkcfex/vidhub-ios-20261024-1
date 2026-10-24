import Foundation

/// 一集
struct Episode: Identifiable, Hashable, Codable {
    let index: Int
    let name: String
    let url: String
    var id: Int { index }
}

/// 一条播放线路（采集接口里 vod_play_from / vod_play_url 的一个分组）
struct PlayLine: Identifiable, Hashable, Codable {
    let name: String
    let episodes: [Episode]
    var id: String { name + "#" + (episodes.first?.url ?? "") }
}

/// 一个媒体条目（电影 / 剧集 / 综艺 / 动漫…）
struct MediaItem: Identifiable, Hashable, Codable {
    let sourceId: String
    let id: String
    var name: String
    var pic: String
    var remarks: String
    var year: String
    var area: String
    var typeName: String
    var score: String
    var actors: String
    var director: String
    var summary: String
    var lines: [PlayLine]

    /// 跨源唯一键
    var uid: String { sourceId + "|" + id }
    var posterURL: URL? { URL(string: pic) }
    var scoreValue: Double { Double(score) ?? 0 }
    var hasScore: Bool { scoreValue > 0 }
    var playable: Bool { !lines.isEmpty }
    var episodeCount: Int { lines.first?.episodes.count ?? 0 }
    var metaLine: String {
        [year, area, typeName].filter { !$0.isEmpty }.joined(separator: " · ")
    }
}

/// 一个采集接口
struct MediaSource: Identifiable, Hashable, Codable {
    var id: String
    var name: String
    var api: String
    var enabled: Bool
    var isDemo: Bool

    init(id: String = UUID().uuidString, name: String, api: String, enabled: Bool = true, isDemo: Bool = false) {
        self.id = id
        self.name = name
        self.api = api
        self.enabled = enabled
        self.isDemo = isDemo
    }
}

/// 分类
struct CMSCategory: Identifiable, Hashable, Codable {
    var id: String
    var name: String
}

/// 一条观看记录
struct WatchRecord: Identifiable, Hashable, Codable {
    var uid: String
    var item: MediaItem
    var lineIndex: Int
    var episodeIndex: Int
    var position: Double
    var duration: Double
    var updated: Date

    var id: String { uid }
    var progress: Double { duration > 0 ? min(1, max(0, position / duration)) : 0 }
    var episodeName: String {
        guard lineIndex < item.lines.count, episodeIndex < item.lines[lineIndex].episodes.count else { return "" }
        return item.lines[lineIndex].episodes[episodeIndex].name
    }
    var isFinished: Bool { progress >= 0.95 }
}

/// 首页一条横滑轨
struct Rail: Identifiable {
    let id: String
    let title: String
    let items: [MediaItem]
}

/// 跨源搜索结果
struct SearchHit: Identifiable, Hashable {
    let item: MediaItem
    let sourceName: String
    var sourceCount: Int = 1
    var id: String { item.uid + sourceName }
}
