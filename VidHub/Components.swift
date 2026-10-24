import SwiftUI

// MARK: - 海报

struct PosterImage: View {
    let url: URL?
    let title: String

    var body: some View {
        GeometryReader { geo in
            ZStack {
                PosterPalette.gradient(for: title)
                if let url = url {
                    AsyncImage(url: url) { phase in
                        if let image = phase.image {
                            image.resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width, height: geo.size.height)
                                .clipped()
                        } else if phase.error != nil {
                            placeholder
                        } else {
                            ProgressView().tint(.white.opacity(0.35))
                        }
                    }
                } else {
                    placeholder
                }
            }
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    private var placeholder: some View {
        VStack(spacing: 7) {
            Image(systemName: "play.rectangle.fill")
                .font(.system(size: 20))
                .foregroundColor(.white.opacity(0.22))
            Text(title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundColor(.white.opacity(0.82))
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.8)
                .padding(.horizontal, 10)
        }
        .padding(6)
    }
}

// MARK: - 评分标签

struct ScoreTag: View {
    let score: String
    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill").font(.system(size: 7, weight: .bold))
            Text(score).font(.system(size: 10, weight: .heavy, design: .rounded))
        }
        .foregroundColor(Theme.gold)
        .padding(.horizontal, 5)
        .padding(.vertical, 3)
        .background(Color.black.opacity(0.55), in: Capsule())
    }
}

// MARK: - 媒体卡片

struct MediaCard: View {
    let item: MediaItem
    var width: CGFloat = 118
    var showTitle: Bool = true

    private var height: CGFloat { width * 1.42 }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            ZStack(alignment: .topTrailing) {
                PosterImage(url: item.posterURL, title: item.name)
                    .frame(width: width, height: height)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Theme.stroke, lineWidth: 0.8)
                    )

                if item.hasScore {
                    ScoreTag(score: item.score).padding(6)
                }

                if !item.remarks.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Text(item.remarks)
                                .font(.system(size: 9, weight: .semibold, design: .rounded))
                                .foregroundColor(.white.opacity(0.92))
                                .lineLimit(1)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 2.5)
                                .background(Color.black.opacity(0.5), in: Capsule())
                            Spacer(minLength: 0)
                        }
                        .padding(6)
                    }
                    .frame(width: width, height: height)
                }
            }

            if showTitle {
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.name)
                        .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                        .foregroundColor(Theme.text)
                        .lineLimit(1)
                    Text(item.metaLine.isEmpty ? " " : item.metaLine)
                        .font(.system(size: 10.5))
                        .foregroundColor(Theme.textFaint)
                        .lineLimit(1)
                }
                .frame(width: width, alignment: .leading)
            }
        }
        .contentShape(Rectangle())
    }
}

// MARK: - 横滑轨

struct RailRow: View {
    let rail: Rail
    var cardWidth: CGFloat = 118

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                Text(rail.title)
                    .font(.system(size: 16.5, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                Text("\(rail.items.count)")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundColor(Theme.textFaint)
                Spacer()
            }
            .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 11) {
                    ForEach(rail.items) { item in
                        NavigationLink(value: item) {
                            MediaCard(item: item, width: cardWidth)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 2)
            }
        }
    }
}

// MARK: - 分类胶囊

struct CategoryChip: View {
    let title: String
    let selected: Bool
    var body: some View {
        Text(title)
            .font(.system(size: 13, weight: selected ? .bold : .medium, design: .rounded))
            .foregroundColor(selected ? .black : Theme.textDim)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(
                Capsule().fill(selected ? Color.white.opacity(0.92) : Color.white.opacity(0.07))
            )
    }
}

// MARK: - 状态占位

struct LoadingRail: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.07))
                .frame(width: 96, height: 15)
                .padding(.horizontal, 16)
            HStack(spacing: 11) {
                ForEach(0..<4, id: \.self) { _ in
                    VStack(alignment: .leading, spacing: 7) {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.055))
                            .frame(width: 118, height: 168)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.045))
                            .frame(width: 80, height: 10)
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    var message: String = ""
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 34, weight: .light))
                .foregroundColor(Theme.textFaint)
            Text(title)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundColor(Theme.textDim)
            if !message.isEmpty {
                Text(message)
                    .font(.system(size: 12.5))
                    .foregroundColor(Theme.textFaint)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }
            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 8)
                        .background(Color.white.opacity(0.9), in: Capsule())
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 34)
    }
}

// MARK: - 小工具

struct TagPill: View {
    let text: String
    var tint: Color = Color.white.opacity(0.09)
    var textColor: Color = Theme.textDim
    var body: some View {
        Text(text)
            .font(.system(size: 10.5, weight: .semibold, design: .rounded))
            .foregroundColor(textColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint, in: Capsule())
    }
}

extension Double {
    var timeText: String {
        guard isFinite, self >= 0 else { return "00:00" }
        let total = Int(self)
        let h = total / 3600
        let m = (total % 3600) / 60
        let s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%02d:%02d", m, s)
    }
}
