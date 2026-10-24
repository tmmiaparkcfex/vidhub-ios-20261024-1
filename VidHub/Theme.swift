import SwiftUI

/// 全局视觉常量。深色影院风格，VidHub 观感。
enum Theme {
    static let bg = Color(red: 0.043, green: 0.035, blue: 0.063)
    static let bgSoft = Color(red: 0.071, green: 0.063, blue: 0.098)
    static let surface = Color(red: 0.086, green: 0.078, blue: 0.118)
    static let surfaceHi = Color(red: 0.133, green: 0.118, blue: 0.176)
    static let stroke = Color.white.opacity(0.075)
    static let text = Color.white.opacity(0.95)
    static let textDim = Color.white.opacity(0.58)
    static let textFaint = Color.white.opacity(0.34)
    static let accent = Color(red: 0.545, green: 0.427, blue: 1.0)
    static let accentSoft = Color(red: 0.545, green: 0.427, blue: 1.0).opacity(0.18)
    static let gold = Color(red: 1.0, green: 0.78, blue: 0.31)

    static var accentGradient: LinearGradient {
        LinearGradient(colors: [Color(red: 0.62, green: 0.46, blue: 1.0), Color(red: 0.42, green: 0.30, blue: 0.92)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

extension View {
    /// 统一圆角裁切
    func roundedCard(_ radius: CGFloat = 14) -> some View {
        clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// 毛玻璃底栏
    func glassBar() -> some View {
        background(.ultraThinMaterial, in: Rectangle())
    }
}

/// 根据字符串稳定生成海报占位色
enum PosterPalette {
    static let pairs: [(Color, Color)] = [
        (Color(red: 0.24, green: 0.16, blue: 0.42), Color(red: 0.09, green: 0.07, blue: 0.17)),
        (Color(red: 0.13, green: 0.24, blue: 0.40), Color(red: 0.06, green: 0.09, blue: 0.16)),
        (Color(red: 0.38, green: 0.16, blue: 0.28), Color(red: 0.12, green: 0.06, blue: 0.12)),
        (Color(red: 0.12, green: 0.30, blue: 0.28), Color(red: 0.05, green: 0.11, blue: 0.11)),
        (Color(red: 0.36, green: 0.26, blue: 0.12), Color(red: 0.13, green: 0.10, blue: 0.06)),
        (Color(red: 0.22, green: 0.16, blue: 0.46), Color(red: 0.08, green: 0.06, blue: 0.18)),
    ]

    static func index(for seed: String) -> Int {
        var h = 5381
        for u in seed.unicodeScalars { h = (h &* 33) &+ Int(u.value) }
        return abs(h) % pairs.count
    }

    static func colors(for seed: String) -> (Color, Color) {
        pairs[index(for: seed)]
    }

    static func gradient(for seed: String) -> LinearGradient {
        let c = colors(for: seed)
        return LinearGradient(colors: [c.0, c.1], startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}
