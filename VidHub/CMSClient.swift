import Foundation
import CoreFoundation

enum CMSError: LocalizedError {
    case badURL
    case http(Int)
    case parse
    case empty
    case tvboxParse

    var errorDescription: String? {
        switch self {
        case .badURL: return "接口地址无效"
        case .http(let code): return "接口返回 HTTP \(code)"
        case .parse: return "接口返回内容无法解析，可能不是采集接口"
        case .empty: return "接口没有返回数据"
        case .tvboxParse: return "不是可识别的 TVBox 配置"
        }
    }
}

struct CMSResult {
    var items: [MediaItem] = []
    var page: Int = 1
    var pageCount: Int = 1
    var total: Int = 0
    var categories: [CMSCategory] = []
}

/// 苹果CMS V10 / TVBox 采集接口适配。兼容 JSONP、BOM、GB18030 编码与常见字段差异。
struct CMSClient {
    static let shared = CMSClient()
    private let session: URLSession

    init() {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest = 15
        cfg.timeoutIntervalForResource = 25
        cfg.requestCachePolicy = .reloadIgnoringLocalCacheData
        cfg.httpAdditionalHeaders = [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
            "Accept": "text/html,application/json,*/*",
        ]
        session = URLSession(configuration: cfg)
    }

    // MARK: - 底层请求

    func rawRequest(_ api: String, params: [String: String]) async throws -> [String: Any] {
        guard var comps = URLComponents(string: api) else { throw CMSError.badURL }
        var query = comps.queryItems ?? []
        for (k, v) in params where !v.isEmpty {
            query.removeAll { $0.name == k }
            query.append(URLQueryItem(name: k, value: v))
        }
        comps.queryItems = query
        guard let url = comps.url else { throw CMSError.badURL }

        let (data, resp) = try await session.data(from: url)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CMSError.http(http.statusCode)
        }
        guard let obj = CMSClient.jsonObject(from: CMSClient.decodeText(data)) else {
            throw CMSError.parse
        }
        return obj
    }

    static func decodeText(_ data: Data) -> String {
        if let s = String(data: data, encoding: .utf8) {
            return s.replacingOccurrences(of: "\u{FEFF}", with: "")
        }
        let gb = CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue))
        if let s = String(data: data, encoding: String.Encoding(rawValue: gb)) { return s }
        return String(decoding: data, as: UTF8.self)
    }

    static func jsonObject(from text: String) -> [String: Any]? {
        let body = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if let d = body.data(using: .utf8),
           let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] {
            return o
        }
        // 兜底：截取第一个 { 到最后一个 }（去掉 JSONP 包裹、前后杂质）
        guard let s = body.firstIndex(of: "{"), let e = body.lastIndex(of: "}"), s <= e else { return nil }
        let slice = String(body[s...e])
        guard let d = slice.data(using: .utf8),
              let o = try? JSONSerialization.jsonObject(with: d) as? [String: Any] else { return nil }
        return o
    }

    // MARK: - 分类

    func categories(_ api: String) async throws -> [CMSCategory] {
        let json = try await rawRequest(api, params: ["ac": "list"])
        var out: [CMSCategory] = []
        if let arr = json["class"] as? [[String: Any]] {
            for d in arr {
                let id = CMSClient.text(d, ["type_id"])
                let name = CMSClient.text(d, ["type_name"])
                if !id.isEmpty && !name.isEmpty {
                    out.append(CMSCategory(id: id, name: name))
                }
            }
        }
        return out
    }

    /// 仅用于接口连通性测试
    func probe(_ api: String) async throws -> Int {
        let json = try await rawRequest(api, params: ["ac": "list", "pg": "1"])
        let arr = json["list"] as? [[String: Any]] ?? []
        if arr.isEmpty && (json["code"] == nil && json["list"] == nil) { throw CMSError.parse }
        return arr.count
    }

    // MARK: - 列表

    func list(_ api: String,
              sourceId: String,
              typeId: String?,
              page: Int,
              keyword: String?) async throws -> CMSResult {
        var params = ["ac": "videolist", "pg": String(page)]
        if let t = typeId, !t.isEmpty { params["t"] = t }
        if let k = keyword, !k.isEmpty { params["wd"] = k }

        var json = try await rawRequest(api, params: params)
        var arr = json["list"] as? [[String: Any]] ?? []
        if arr.isEmpty {
            params["ac"] = "detail"
            if let second = try? await rawRequest(api, params: params) {
                let secondArr = second["list"] as? [[String: Any]] ?? []
                if !secondArr.isEmpty {
                    json = second
                    arr = secondArr
                }
            }
        }

        var result = CMSResult()
        result.items = arr.compactMap { CMSClient.item(from: $0, sourceId: sourceId) }
        result.page = Int(CMSClient.text(json, ["page"])) ?? page
        result.pageCount = Int(CMSClient.text(json, ["pagecount"])) ?? 1
        result.total = Int(CMSClient.text(json, ["total"])) ?? result.items.count
        if let cls = json["class"] as? [[String: Any]] {
            result.categories = cls.compactMap { d in
                let id = CMSClient.text(d, ["type_id"])
                let name = CMSClient.text(d, ["type_name"])
                return (id.isEmpty || name.isEmpty) ? nil : CMSCategory(id: id, name: name)
            }
        }
        if arr.isEmpty && result.total == 0 && json["code"] == nil {
            throw CMSError.parse
        }
        return result
    }

    // MARK: - 详情

    func detail(_ api: String, sourceId: String, id: String) async throws -> MediaItem? {
        let json = try await rawRequest(api, params: ["ac": "videolist", "ids": id])
        if let arr = json["list"] as? [[String: Any]], let first = arr.first,
           let item = CMSClient.item(from: first, sourceId: sourceId) {
            return item
        }
        let json2 = try await rawRequest(api, params: ["ac": "detail", "ids": id])
        if let arr = json2["list"] as? [[String: Any]], let first = arr.first {
            return CMSClient.item(from: first, sourceId: sourceId)
        }
        return nil
    }

    // MARK: - 字段解析

    static func text(_ d: [String: Any], _ keys: [String]) -> String {
        for k in keys {
            if let v = d[k] as? String {
                let t = v.trimmingCharacters(in: .whitespacesAndNewlines)
                if !t.isEmpty { return t }
            } else if let n = d[k] as? NSNumber {
                return n.stringValue
            } else if let n = d[k] as? Int {
                return String(n)
            } else if let n = d[k] as? Double {
                return String(format: "%.1f", n)
            }
        }
        return ""
    }

    static func clean(_ html: String) -> String {
        var s = html
        s = s.replacingOccurrences(of: "<br\\s*/?>", with: "\n", options: .regularExpression)
        s = s.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        s = s.replacingOccurrences(of: "&nbsp;", with: " ")
        s = s.replacingOccurrences(of: "&amp;", with: "&")
        s = s.replacingOccurrences(of: "&quot;", with: "\"")
        s = s.replacingOccurrences(of: "&lt;", with: "<")
        s = s.replacingOccurrences(of: "&gt;", with: ">")
        s = s.replacingOccurrences(of: "\r", with: "")
        return s.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func item(from d: [String: Any], sourceId: String) -> MediaItem? {
        let id = text(d, ["vod_id", "id", "vodId"])
        let name = text(d, ["vod_name", "name", "title"])
        guard !id.isEmpty, !name.isEmpty else { return nil }

        var score = text(d, ["vod_score", "score"])
        if score == "0" || score == "0.0" || score == "0.00" { score = "" }

        var pic = text(d, ["vod_pic", "pic", "cover", "vod_pic_thumb"])
        if pic.hasPrefix("//") { pic = "https:" + pic }

        return MediaItem(
            sourceId: sourceId,
            id: id,
            name: name,
            pic: pic,
            remarks: text(d, ["vod_remarks", "remarks", "note"]),
            year: text(d, ["vod_year", "year"]),
            area: text(d, ["vod_area", "area"]),
            typeName: text(d, ["vod_class", "type_name", "class"]),
            score: score,
            actors: clean(text(d, ["vod_actor", "actor"])),
            director: clean(text(d, ["vod_director", "director"])),
            summary: clean(text(d, ["vod_content", "vod_blurb", "content", "des"])),
            lines: playLines(d)
        )
    }

    static func playLines(_ d: [String: Any]) -> [PlayLine] {
        let froms = text(d, ["vod_play_from", "play_from"]).components(separatedBy: "$$$")
        let groups = text(d, ["vod_play_url", "play_url"]).components(separatedBy: "$$$")
        var out: [PlayLine] = []
        for (gi, group) in groups.enumerated() {
            guard !group.isEmpty else { continue }
            let lineName = gi < froms.count && !froms[gi].isEmpty ? froms[gi] : "线路\(gi + 1)"
            var eps: [Episode] = []
            for part in group.components(separatedBy: "#") {
                let seg = part.components(separatedBy: "$")
                let rawName = seg.count > 1 ? seg[0] : ""
                let rawURL = seg.count > 1 ? seg[1] : seg[0]
                let url = rawURL.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !url.isEmpty else { continue }
                let epName = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
                eps.append(Episode(index: eps.count,
                                   name: epName.isEmpty ? "第\(eps.count + 1)集" : epName,
                                   url: url))
            }
            if !eps.isEmpty { out.append(PlayLine(name: lineName, episodes: eps)) }
        }
        return out
    }

    // MARK: - TVBox 配置导入

    /// 从 TVBox 配置 JSON 里抽出可用的 CMS 采集接口
    func sources(fromTVBoxJSON json: [String: Any]) throws -> [MediaSource] {
        guard let sites = json["sites"] as? [[String: Any]] else { throw CMSError.tvboxParse }
        var out: [MediaSource] = []
        for s in sites {
            let api = CMSClient.text(s, ["api"])
            guard api.lowercased().hasPrefix("http") else { continue }
            let lower = api.lowercased()
            let looksCMS = lower.contains("api.php") || lower.contains("provide/vod") || lower.contains("/vod/") || lower.contains("inc/api")
            guard looksCMS else { continue }
            if out.contains(where: { $0.api == api }) { continue }
            let name = CMSClient.text(s, ["name"]).isEmpty ? "源\(out.count + 1)" : CMSClient.text(s, ["name"])
            out.append(MediaSource(name: name, api: api))
        }
        if out.isEmpty { throw CMSError.tvboxParse }
        return out
    }

    func loadTVBoxConfig(url: String) async throws -> [MediaSource] {
        guard let u = URL(string: url) else { throw CMSError.badURL }
        let (data, resp) = try await session.data(from: u)
        if let http = resp as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw CMSError.http(http.statusCode)
        }
        guard let json = CMSClient.jsonObject(from: CMSClient.decodeText(data)) else { throw CMSError.tvboxParse }
        return try sources(fromTVBoxJSON: json)
    }
}
