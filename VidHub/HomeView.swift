import SwiftUI

struct HomeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @State private var quickPlay: PlayerTarget?
    @State private var showSettings = false

    private var hero: MediaItem? {
        model.rails.first(where: { $0.id == "top" })?.items.first
            ?? model.rails.first?.items.first
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 22) {
                        header

                        if let hero = hero {
                            HeroCard(item: hero) {
                                quickPlay = PlayerTarget(item: hero, lineIndex: 0, episodeIndex: 0)
                            }
                            .padding(.horizontal, 16)
                        }

                        if model.isLoadingHome && model.rails.isEmpty {
                            LoadingRail()
                            LoadingRail()
                        }

                        if !library.continueWatching.isEmpty {
                            continueRail
                        }

                        ForEach(model.rails) { rail in
                            RailRow(rail: rail)
                        }

                        if let err = model.homeError, model.rails.isEmpty {
                            EmptyStateView(icon: "wifi.exclamationmark",
                                           title: "没有加载到内容",
                                           message: err,
                                           actionTitle: "重试") {
                                Task { await model.loadHome() }
                            }
                        }

                        footer
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 28)
                }
                .refreshable { await model.loadHome() }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: MediaItem.self) { item in
                DetailView(item: item)
            }
            .fullScreenCover(item: $quickPlay) { target in
                PlayerView(target: target)
            }
            .sheet(isPresented: $showSettings) {
                MeView(asSheet: true)
            }
            .task {
                if model.rails.isEmpty { await model.loadHome() }
            }
        }
    }

    // MARK: - 顶栏

    private var header: some View {
        HStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: "play.fill")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(.black)
                    .frame(width: 22, height: 22)
                    .background(Theme.accentGradient, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                Text("VidHub")
                    .font(.system(size: 18, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text)
            }

            Spacer()

            Menu {
                ForEach(model.sources) { source in
                    Button {
                        model.setActive(source.id)
                    } label: {
                        if source.id == model.activeSourceID {
                            Label(source.name, systemImage: "checkmark")
                        } else {
                            Text(source.name)
                        }
                    }
                }
                Divider()
                Button {
                    showSettings = true
                } label: {
                    Label("管理接口", systemImage: "slider.horizontal.3")
                }
            } label: {
                HStack(spacing: 4) {
                    Text(model.activeSource?.name ?? "选择源")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                }
                .foregroundColor(Theme.text)
                .padding(.horizontal, 11)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.08), in: Capsule())
                .overlay(Capsule().stroke(Theme.stroke, lineWidth: 0.8))
            }

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Theme.textDim)
                    .frame(width: 30, height: 30)
                    .background(Color.white.opacity(0.06), in: Circle())
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - 继续观看

    private var continueRail: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("继续观看")
                .font(.system(size: 16.5, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 16)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 11) {
                    ForEach(library.continueWatching.prefix(10)) { record in
                        Button {
                            quickPlay = PlayerTarget(item: record.item,
                                                     lineIndex: record.lineIndex,
                                                     episodeIndex: record.episodeIndex)
                        } label: {
                            VStack(alignment: .leading, spacing: 7) {
                                ZStack(alignment: .bottomLeading) {
                                    PosterImage(url: record.item.posterURL, title: record.item.name)
                                        .frame(width: 150, height: 86)
                                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 11, style: .continuous)
                                                .stroke(Theme.stroke, lineWidth: 0.8)
                                        )
                                    LinearGradient(colors: [.clear, .black.opacity(0.7)],
                                                   startPoint: .center, endPoint: .bottom)
                                        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                                        .frame(height: 44)
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                    HStack(spacing: 4) {
                                        Image(systemName: "play.fill").font(.system(size: 8, weight: .black))
                                        Text(record.episodeName).lineLimit(1)
                                    }
                                    .font(.system(size: 9.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white.opacity(0.92))
                                    .padding(.horizontal, 6)
                                    .padding(.bottom, 6)
                                    .padding(.leading, 2)

                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            Capsule().fill(Color.white.opacity(0.22))
                                            Capsule().fill(Theme.accentGradient)
                                                .frame(width: max(2, geo.size.width * record.progress))
                                        }
                                        .frame(height: 2.5)
                                        .frame(maxHeight: .infinity, alignment: .bottom)
                                        .padding(.horizontal, 6)
                                        .padding(.bottom, 2)
                                    }
                                }
                                .frame(width: 150, height: 86)

                                Text(record.item.name)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(Theme.text)
                                    .lineLimit(1)
                                Text("看到 \(record.position.timeText)")
                                    .font(.system(size: 10))
                                    .foregroundColor(Theme.textFaint)
                                    .lineLimit(1)
                            }
                            .frame(width: 150, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private var footer: some View {
        VStack(spacing: 4) {
            Text(model.activeSource?.isDemo == true ? "当前为演示源，数据为本地虚构内容" : "内容来自你添加的采集接口，仅限个人观看")
                .font(.system(size: 10.5))
                .foregroundColor(Theme.textFaint)
            if let t = model.lastUpdated {
                Text("更新于 " + t.formatted(date: .omitted, time: .shortened))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textFaint.opacity(0.7))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }
}

// MARK: - 首页头图

struct HeroCard: View {
    let item: MediaItem
    var onPlay: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            PosterImage(url: item.posterURL, title: item.name)
                .frame(height: 248)
                .blur(radius: 0.5)
                .overlay(
                    LinearGradient(stops: [
                        .init(color: .clear, location: 0.18),
                        .init(color: Theme.bg.opacity(0.55), location: 0.55),
                        .init(color: Theme.bg.opacity(0.96), location: 0.92),
                    ], startPoint: .top, endPoint: .bottom)
                )

            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 6) {
                    if !item.remarks.isEmpty {
                        Text(item.remarks)
                            .font(.system(size: 9.5, weight: .heavy, design: .rounded))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.white.opacity(0.92), in: Capsule())
                    }
                    if item.hasScore {
                        ScoreTag(score: item.score)
                    }
                    Spacer()
                }

                Text(item.name)
                    .font(.system(size: 25, weight: .heavy, design: .rounded))
                    .foregroundColor(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                Text(item.metaLine)
                    .font(.system(size: 11.5, weight: .medium))
                    .foregroundColor(.white.opacity(0.62))

                Text(item.summary)
                    .font(.system(size: 11.5))
                    .foregroundColor(.white.opacity(0.55))
                    .lineLimit(2)
                    .lineSpacing(1.5)
                    .padding(.trailing, 30)

                HStack(spacing: 9) {
                    Button(action: onPlay) {
                        HStack(spacing: 5) {
                            Image(systemName: "play.fill").font(.system(size: 11, weight: .black))
                            Text("播放").font(.system(size: 13, weight: .bold, design: .rounded))
                        }
                        .foregroundColor(.black)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 9)
                        .background(Color.white.opacity(0.95), in: Capsule())
                    }

                    NavigationLink(value: item) {
                        HStack(spacing: 5) {
                            Image(systemName: "info.circle").font(.system(size: 11, weight: .bold))
                            Text("详情").font(.system(size: 13, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(Theme.text)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 9)
                        .background(.ultraThinMaterial, in: Capsule())
                    }
                }
                .padding(.top, 2)
            }
            .padding(14)
        }
        .frame(height: 248)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Theme.stroke, lineWidth: 0.8)
        )
    }
}
