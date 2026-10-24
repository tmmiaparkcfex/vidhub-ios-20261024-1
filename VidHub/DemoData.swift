import Foundation

/// 内置演示源：不联网也能完整体验界面与播放流程。
/// 片名为虚构，播放地址使用公开测试流，仅用于验证播放器。
enum DemoData {
    static let sourceId = "demo"

    static let categories: [CMSCategory] = [
        CMSCategory(id: "1", name: "电影"),
        CMSCategory(id: "2", name: "剧集"),
        CMSCategory(id: "3", name: "综艺"),
        CMSCategory(id: "4", name: "动漫"),
        CMSCategory(id: "5", name: "纪录片"),
    ]

    private static let streams: [String] = [
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/img_bipbop_adv_example_fmp4/master.m3u8",
        "https://test-streams.mux.dev/x36xhzz/x36xhzz.m3u8",
        "https://devstreaming-cdn.apple.com/videos/streaming/examples/bipbop_16x9/bipbop_16x9_variant.m3u8",
    ]

    static let all: [MediaItem] = [
        make(1, "雾港", "1", "2024", "8.6", "HD 国语", "中国大陆", "一场大雾封住了整座港口，刑警与失踪者的妻子在四十小时里互相试探，谁都没有说出最后一句话。"),
        make(2, "长夜将尽", "1", "2023", "8.1", "HD 国语", "中国大陆", "三个陌生人在末班地铁上相遇，天亮之前他们必须决定谁可以活下去。"),
        make(3, "第七日黎明", "1", "2025", "7.9", "抢先版", "美国", "时间在第七天停止循环，唯一记得昨天的人开始怀疑自己才是变量。"),
        make(4, "铁皮心跳", "1", "2022", "8.8", "HD 中字", "日本", "废弃工厂里的机器人学会了说谎，而它说的第一个谎是「我不疼」。"),
        make(5, "静默航线", "1", "2021", "7.6", "HD 国语", "中国大陆", "一架失联七年的航班突然降落，机上乘客一个都没有变老。"),
        make(6, "山海档案", "2", "2025", "9.1", "更新至12集", "中国大陆", "地方志办公室的年轻人翻出一批旧档案，发现每个消失的村庄都记录在同一页纸上。"),
        make(7, "双城迷雾", "2", "2024", "8.4", "更新至08集", "中国大陆", "两座城市同时发生一模一样的凶案，办案的两个人却在不同的年份。"),
        make(8, "逆光而行", "2", "2023", "8.9", "全24集", "韩国", "一名记者用十年时间追查一条被删掉的新闻，代价是所有人都忘了她。"),
        make(9, "深水区", "2", "2026", "8.2", "更新至06集", "中国大陆", "潜水员在水下发现一扇门，门后有灯还亮着。"),
        make(10, "无声之城", "2", "2022", "8.7", "全16集", "英国", "全城的人一夜之间失去语言，只有手语老师听见了一个孩子在唱歌。"),
        make(11, "周末实验室", "3", "2026", "7.8", "更新至10期", "中国大陆", "每期把三个不靠谱的猜想交给真正的科学家去实现。"),
        make(12, "三十天环岛", "3", "2025", "8.0", "全12期", "中国台湾", "六个人只带两百块，用三十天绕岛一圈，规则是不能求助。"),
        make(13, "厨房夜谈", "3", "2024", "8.3", "全20期", "中国大陆", "深夜厨房只开四小时，来的人点一道菜，讲一个不想带回家的故事。"),
        make(14, "声音的边界", "3", "2025", "8.5", "更新至07期", "中国大陆", "让歌手去听自己听不见的频率，再把那段声音写成歌。"),
        make(15, "荒野搭子", "3", "2023", "7.5", "全10期", "中国大陆", "两个互不相识的人被丢进同一片荒野，只有一把刀和一整天。"),
        make(16, "星轨少年", "4", "2025", "9.2", "更新至24话", "日本", "修船厂的少年捡到一颗会做梦的星核，梦境正在改写整个星系。"),
        make(17, "机械之诗", "4", "2024", "8.8", "全12话", "日本", "战争结束后，最后一台机甲被派去种地，它开始写诗。"),
        make(18, "云上牧场", "4", "2023", "8.0", "全26话", "中国大陆", "云层之上的牧场养的是天气，牧羊人每天要把雨赶到需要的地方。"),
        make(19, "灰烬学院", "4", "2026", "8.6", "更新至09话", "中国大陆", "所有毕业生都会遗忘在校的七年，只有留级生记得。"),
        make(20, "海雾信使", "4", "2022", "8.4", "全14话", "日本", "海雾里每天送来一封信，收信人是一个还没出生的人。"),
        make(21, "大地脉动", "5", "2025", "9.3", "全6集", "英国", "用一年时间记录一条河流从雪线到入海的全部呼吸。"),
        make(22, "城市的呼吸", "5", "2024", "8.7", "全8集", "中国大陆", "凌晨三点的城市属于另一群人，镜头跟着他们走了一整年。"),
        make(23, "手艺人", "5", "2023", "8.9", "全10集", "中国大陆", "十位匠人，十种快要消失的手感，每一集只讲一道工序。"),
        make(24, "冰层之下", "5", "2026", "9.0", "更新至04集", "挪威", "钻透四千米冰层之后，科研队听见了不该存在的声音。"),
        make(25, "丝路残卷", "5", "2022", "8.5", "全6集", "中国大陆", "沿着残存的文书碎片，重走一条没有被写进史书的商道。"),
    ]

    private static func make(_ id: Int, _ name: String, _ typeId: String,
                             _ year: String, _ score: String, _ remarks: String,
                             _ area: String, _ desc: String) -> MediaItem {
        let typeName = categories.first { $0.id == typeId }?.name ?? ""
        let epCount: Int
        switch typeId {
        case "1": epCount = 1
        case "3": epCount = 10
        case "5": epCount = 6
        default: epCount = 12
        }
        var lines: [PlayLine] = []
        let primary = (0..<epCount).map { i in
            Episode(index: i,
                    name: epCount == 1 ? "正片" : (typeId == "3" ? "第\(i + 1)期" : "第\(i + 1)集"),
                    url: streams[(id + i) % streams.count])
        }
        lines.append(PlayLine(name: "线路一", episodes: primary))
        if id % 3 == 0 {
            let backup = (0..<epCount).map { i in
                Episode(index: i,
                        name: epCount == 1 ? "正片" : (typeId == "3" ? "第\(i + 1)期" : "第\(i + 1)集"),
                        url: streams[(id + i + 1) % streams.count])
            }
            lines.append(PlayLine(name: "线路二", episodes: backup))
        }
        return MediaItem(sourceId: sourceId,
                         id: String(id),
                         name: name,
                         pic: "",
                         remarks: remarks,
                         year: year,
                         area: area,
                         typeName: typeName,
                         score: score,
                         actors: "演示演员 A · 演示演员 B · 演示演员 C",
                         director: "演示导演",
                         summary: desc,
                         lines: lines)
    }

    static func items(typeId: String?, page: Int, pageSize: Int = 18) -> (items: [MediaItem], hasMore: Bool) {
        let pool = typeId == nil || typeId!.isEmpty ? all : all.filter { item in
            categories.first { $0.id == typeId }?.name == item.typeName
        }
        let start = max(0, (page - 1) * pageSize)
        guard start < pool.count else { return ([], false) }
        let end = min(pool.count, start + pageSize)
        return (Array(pool[start..<end]), end < pool.count)
    }

    static func search(_ keyword: String) -> [MediaItem] {
        let k = keyword.trimmingCharacters(in: .whitespaces)
        guard !k.isEmpty else { return [] }
        return all.filter { $0.name.contains(k) || $0.summary.contains(k) || $0.actors.contains(k) }
    }

    static func item(id: String) -> MediaItem? {
        all.first { $0.id == id }
    }

    static var featured: MediaItem { all[0] }
}
