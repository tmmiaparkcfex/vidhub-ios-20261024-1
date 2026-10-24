import SwiftUI

struct DetailView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    @State private var item: MediaItem
    @State private var lineIndex = 0
    @State private var playerTarget: PlayerTarget?
    @State private var expanded = false

    init(item: MediaItem) {
        _item = State(initialValue: item)
    }

    private var lines: [PlayLine] { item.lines }

    private var resumeRecord: WatchRecord? { library.latestRecord(for: item) }

    var body: some View {
        ZStack(alignment: .top) {
            Theme.bg.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    backdrop
                    titleBlock
                    actionRow
                    summaryBlock
                    if !lines.isEmpty { linePicker }
                    if !lines.isEmpty { episodeGrid }
                    infoBlock
                }
                .padding(.bottom, 30)
            }
            .ignoresSafeArea(edges: .top)

            topBar
        }
        .navigationBarBackButtonHidden(true)
        .task {
            let fresh = await model.fetchDetail(item)
            if fresh.uid == item.uid, fresh.playable {
                item = fresh
                if lineIndex >= fresh.lines.count { lineIndex = 0 }
            }
        }
        .fullScreenCover(item: $playerTarget) { target in
            PlayerView(target: target)
        }
    }

    // MARK: - 顶栏

    private var topBar: some View {
        HStack {
            Button { dismiss() } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(.white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
            }
            Spacer()
            Button {
                library.toggleFavorite(item)
            } label: {
                Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(library.isFavorite(item) ? Theme.accent : .white)
                    .frame(width: 32, height: 32)
                    .background(Color.black.opacity(0.35), in: Circle())
                    .background(.ultraThinMaterial, in: Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 背景

    private var backdrop: some View {
        ZStack(alignment: .bottom) {
            PosterImage(url: item.posterURL, title: item.name)
                .frame(height: 250)
                .blur(radius: 16)
                .opacity(0.55)
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.3),
                        .init(color: Theme.bg.opacity(0.7), location: 0.72),
                        .init(color: Theme.bg, location: 1),
                    ], startPoint: .top, endPoint: .bottom)
                )
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .clipped()
    }

    private var titleBlock: some View {
        HStack(alignment: .top, spacing: 13) {
            PosterImage(url: item.posterURL, title: item.name)
                .frame(width: 96, height: 136)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Theme.stroke, lineWidth: 0.8)
                )

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 21, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)

                HStack(spacing: 6) {
                    if item.hasScore {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill").font(.system(size: 8, weight: .bold))
                            Text(item.score).font(.system(size: 12, weight: .heavy, design: .rounded))
                        }
                        .foregroundColor(Theme.gold)
                    }
                    if !item.year.isEmpty { TagPill(text: item.year) }
                    if !item.area.isEmpty { TagPill(text: item.area) }
                }

                if !item.typeName.isEmpty {
                    Text(item.typeName)
                        .font(.system(size: 11.5))
                        .foregroundColor(Theme.textDim)
                }

                if !item.director.isEmpty {
                    Text("导演 " + item.director)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textFaint)
                        .lineLimit(1)
                }
                if !item.actors.isEmpty {
                    Text("主演 " + item.actors)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textFaint)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(spacing: 5) {
                    Image(systemName: "rectangle.stack.badge.play")
                        .font(.system(size: 9, weight: .bold))
                    Text(item.episodeCount > 1 ? "共 \(item.episodeCount) 集 · \(lines.count) 条线路" : "\(lines.count) 条线路")
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundColor(Theme.textFaint)
            }
            .frame(height: 136, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.top, -46)
    }

    private var actionRow: some View {
        HStack(spacing: 10) {
            Button {
                startPlay(episodeIndex: resumeRecord?.episodeIndex ?? 0,
                          lineIndex: resumeRecord?.lineIndex ?? 0)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.fill").font(.system(size: 12, weight: .black))
                    Text(playButtonTitle).font(.system(size: 14, weight: .bold, design: .rounded))
                }
                .foregroundColor(.black)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.95), in: Capsule())
            }
            .disabled(lines.isEmpty)

            Button {
                library.toggleFavorite(item)
            } label: {
                VStack(spacing: 3) {
                    Image(systemName: library.isFavorite(item) ? "heart.fill" : "heart")
                        .font(.system(size: 15, weight: .semibold))
                    Text(library.isFavorite(item) ? "已收藏" : "收藏")
                        .font(.system(size: 9, weight: .medium))
                }
                .foregroundColor(library.isFavorite(item) ? Theme.accent : Theme.textDim)
                .frame(width: 58, height: 46)
                .background(Color.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
        }
        .padding(.horizontal, 16)
    }

    private var playButtonTitle: String {
        guard let r = resumeRecord, !r.isFinished, r.position > 5 else {
            return item.episodeCount > 1 ? "播放第 1 集" : "立即播放"
        }
        return "续看 " + r.episodeName
    }

    private var summaryBlock: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("简介")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
            Text(item.summary.isEmpty ? "暂无简介" : item.summary)
                .font(.system(size: 12.5))
                .foregroundColor(Theme.textDim)
                .lineSpacing(3)
                .lineLimit(expanded ? nil : 3)
                .fixedSize(horizontal: false, vertical: true)
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                Text(expanded ? "收起" : "展开")
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundColor(Theme.accent)
            }
        }
        .padding(.horizontal, 16)
    }

    private var linePicker: some View {
        VStack(alignment: .leading, spacing: 9) {
            Text("播放线路")
                .font(.system(size: 13.5, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { idx, line in
                        Button {
                            lineIndex = idx
                        } label: {
                            HStack(spacing: 5) {
                                Text(line.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                Text("\(line.episodes.count)")
                                    .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                    .foregroundColor(lineIndex == idx ? Color.black.opacity(0.45) : Theme.textFaint)
                            }
                            .foregroundColor(lineIndex == idx ? .black : Theme.textDim)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(
                                Capsule().fill(lineIndex == idx ? Color.white.opacity(0.92) : Color.white.opacity(0.06))
                            )
                        }
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var episodeGrid: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("选集")
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                Text("\(lines[lineIndex].episodes.count) 集")
                    .font(.system(size: 10.5))
                    .foregroundColor(Theme.textFaint)
                Spacer()
            }
            .padding(.horizontal, 16)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                ForEach(lines[lineIndex].episodes) { ep in
                    Button {
                        startPlay(episodeIndex: ep.index, lineIndex: lineIndex)
                    } label: {
                        Text(shortEpisodeName(ep.name, index: ep.index))
                            .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                            .foregroundColor(Theme.textDim)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 9)
                            .background(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(Color.white.opacity(0.055))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .stroke(Theme.stroke, lineWidth: 0.8)
                            )
                    }
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func shortEpisodeName(_ name: String, index: Int) -> String {
        if name.count <= 8 { return name }
        return "第\(index + 1)集"
    }

    private var infoBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider().background(Theme.stroke)
            HStack(spacing: 4) {
                Image(systemName: "dot.radiowaves.left.and.right").font(.system(size: 8, weight: .bold))
                Text("来源：\(model.sourceName(for: item.sourceId))")
                    .font(.system(size: 10.5))
            }
            .foregroundColor(Theme.textFaint)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private func startPlay(episodeIndex: Int, lineIndex: Int) {
        guard !lines.isEmpty else { return }
        let safeLine = min(max(0, lineIndex), lines.count - 1)
        let eps = lines[safeLine].episodes
        guard !eps.isEmpty else { return }
        let safeEp = min(max(0, episodeIndex), eps.count - 1)
        playerTarget = PlayerTarget(item: item, lineIndex: safeLine, episodeIndex: safeEp)
    }
}
