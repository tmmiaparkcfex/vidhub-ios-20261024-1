import SwiftUI
import AVKit
import MediaPlayer
import UIKit

// MARK: - 播放目标

struct PlayerTarget: Identifiable {
    let item: MediaItem
    var lineIndex: Int
    var episodeIndex: Int
    var id: String { item.uid + "-\(lineIndex)-\(episodeIndex)" }
}

// MARK: - 播放内核

final class PlayerEngine: ObservableObject {
    let player = AVPlayer()

    @Published var isPlaying = false
    @Published var time: Double = 0
    @Published var duration: Double = 0
    @Published var buffering = false
    @Published var failed: String?
    @Published var ready = false
    @Published var rate: Float = 1

    var onEnd: (() -> Void)?
    var onNext: (() -> Void)?
    private var remoteConfigured = false
    private var timeObserver: Any?
    private var statusObs: NSKeyValueObservation?
    private var timeControlObs: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?

    init() {
        player.actionAtItemEnd = .pause
        player.allowsExternalPlayback = true
        player.usesExternalPlaybackWhileExternalScreenIsActive = true
        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.5, preferredTimescale: 600),
            queue: .main
        ) { [weak self] t in
            guard let self = self else { return }
            let sec = t.seconds
            if sec.isFinite { self.time = sec }
            if let d = self.player.currentItem?.duration.seconds, d.isFinite, d > 0 {
                self.duration = d
            }
        }
    }

    deinit {
        if let o = timeObserver { player.removeTimeObserver(o) }
        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
    }

    func activateAudio() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .moviePlayback)
        try? session.setActive(true)
    }

    /// 锁屏 / 耳机线控
    func configureRemoteCommands() {
        guard !remoteConfigured else { return }
        remoteConfigured = true
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in
            self?.play()
            return .success
        }
        center.pauseCommand.addTarget { [weak self] _ in
            self?.pause()
            return .success
        }
        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            self?.toggle()
            return .success
        }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let e = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            self.seek(to: e.positionTime)
            return .success
        }
        center.nextTrackCommand.addTarget { [weak self] _ in
            self?.onNext?()
            return .success
        }
    }

    func load(url: URL, startAt: Double) {
        failed = nil
        ready = false
        duration = 0
        time = 0
        buffering = true

        let asset = AVURLAsset(url: url, options: ["AVURLAssetHTTPHeaderFieldsKey": [
            "User-Agent": "Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.0 Mobile/15E148 Safari/604.1",
        ]])
        let item = AVPlayerItem(asset: asset)
        item.preferredForwardBufferDuration = 6

        statusObs = item.observe(\.status, options: [.new, .initial]) { [weak self] it, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                switch it.status {
                case .readyToPlay:
                    self.ready = true
                    if startAt > 1 {
                        self.player.seek(to: CMTime(seconds: startAt, preferredTimescale: 600),
                                         toleranceBefore: .zero, toleranceAfter: .zero)
                    }
                    self.play()
                case .failed:
                    self.failed = it.error?.localizedDescription ?? "无法播放该地址"
                    self.buffering = false
                default:
                    break
                }
            }
        }

        timeControlObs = player.observe(\.timeControlStatus, options: [.new]) { [weak self] p, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                self.isPlaying = p.timeControlStatus == .playing
                self.buffering = p.timeControlStatus == .waitingToPlayAtSpecifiedRate
            }
        }

        if let e = endObserver { NotificationCenter.default.removeObserver(e) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: item, queue: .main
        ) { [weak self] _ in
            self?.onEnd?()
        }

        player.replaceCurrentItem(with: item)
    }

    func play() {
        player.play()
        player.rate = rate
    }

    func pause() { player.pause() }

    func toggle() {
        if player.timeControlStatus == .playing { pause() } else { play() }
    }

    func setRate(_ r: Float) {
        rate = r
        if player.timeControlStatus == .playing { player.rate = r }
    }

    func seek(to seconds: Double) {
        guard seconds.isFinite else { return }
        let clamped = max(0, min(seconds, duration > 0 ? duration - 0.5 : seconds))
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: .zero, toleranceAfter: .zero)
        time = clamped
    }

    func skip(_ delta: Double) { seek(to: time + delta) }
}

// MARK: - 播放画面 + 画中画

final class PlayerSurfaceView: UIView {
    override class var layerClass: AnyClass { AVPlayerLayer.self }
    var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    private(set) var pip: AVPictureInPictureController?

    func attach(_ player: AVPlayer) {
        playerLayer.player = player
        playerLayer.videoGravity = .resizeAspect
        if AVPictureInPictureController.isPictureInPictureSupported(), pip == nil {
            pip = AVPictureInPictureController(playerLayer: playerLayer)
            pip?.canStartPictureInPictureAutomaticallyFromInline = true
        }
    }
}

final class PiPController: ObservableObject {
    weak var surface: PlayerSurfaceView?
    @Published var active = false
    @Published var available = false

    func refresh() {
        available = AVPictureInPictureController.isPictureInPictureSupported() && surface?.pip != nil
    }

    func toggle() {
        guard let pip = surface?.pip else { return }
        if pip.isPictureInPictureActive {
            pip.stopPictureInPicture()
        } else {
            pip.startPictureInPicture()
        }
        active = pip.isPictureInPictureActive
    }
}

struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer
    let pip: PiPController

    func makeUIView(context: Context) -> PlayerSurfaceView {
        let view = PlayerSurfaceView()
        view.backgroundColor = .black
        view.attach(player)
        pip.surface = view
        DispatchQueue.main.async { pip.refresh() }
        return view
    }

    func updateUIView(_ uiView: PlayerSurfaceView, context: Context) {
        if uiView.playerLayer.player !== player {
            uiView.attach(player)
        }
    }
}

// MARK: - 系统音量

final class SystemVolume {
    static let shared = SystemVolume()
    private let volumeView = MPVolumeView(frame: CGRect(x: -2000, y: -2000, width: 40, height: 40))

    private var slider: UISlider? {
        volumeView.subviews.compactMap { $0 as? UISlider }.first
    }

    func attach() {
        guard volumeView.superview == nil else { return }
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let window = scene?.windows.first else { return }
        volumeView.alpha = 0.02
        window.addSubview(volumeView)
    }

    var value: Float {
        get { AVAudioSession.sharedInstance().outputVolume }
        set {
            attach()
            slider?.value = min(1, max(0, newValue))
        }
    }
}

// MARK: - 播放页

struct PlayerView: View {
    @EnvironmentObject private var library: LibraryStore

    let target: PlayerTarget

    @StateObject private var engine = PlayerEngine()
    @StateObject private var pip = PiPController()

    @State private var item: MediaItem
    @State private var lineIndex: Int
    @State private var episodeIndex: Int

    @State private var showChrome = true
    @State private var showEpisodes = false
    @State private var dragSeek: Double?
    @State private var hud: String?
    @State private var dragStartTime: Double = 0
    @State private var dragMode: DragMode = .none
    @State private var startBrightness: CGFloat = 0
    @State private var startVolume: Float = 0
    @Environment(\.dismiss) private var dismiss
    @AppStorage("vidhub.autoplay") private var autoPlayNext = true
    @AppStorage("vidhub.remember") private var rememberProgress = true

    private enum DragMode: Equatable { case none, seek, brightness, volume }

    private let ticker = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    init(target: PlayerTarget) {
        self.target = target
        _item = State(initialValue: target.item)
        _lineIndex = State(initialValue: target.lineIndex)
        _episodeIndex = State(initialValue: target.episodeIndex)
    }

    private var episodes: [Episode] {
        guard lineIndex < item.lines.count else { return [] }
        return item.lines[lineIndex].episodes
    }

    private var currentEpisode: Episode? {
        episodeIndex < episodes.count ? episodes[episodeIndex] : nil
    }

    private var currentLineName: String {
        lineIndex < item.lines.count ? item.lines[lineIndex].name : ""
    }

    var body: some View {
        GeometryReader { geo in
            let landscape = geo.size.width > geo.size.height
            ZStack {
                Color.black.ignoresSafeArea()

                PlayerLayerView(player: engine.player, pip: pip)
                    .ignoresSafeArea()

                Color.black.opacity(0.001)
                    .ignoresSafeArea()
                    .onTapGesture { withAnimation(.easeOut(duration: 0.18)) { showChrome.toggle() } }
                    .gesture(dragGesture(width: geo.size.width))

                if engine.buffering {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .tint(.white)
                        .scaleEffect(1.4)
                }

                if let failed = engine.failed {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(Theme.gold)
                        Text("播放失败")
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        Text(failed)
                            .font(.system(size: 11.5))
                            .foregroundColor(.white.opacity(0.6))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                        HStack(spacing: 10) {
                            Button("重试") { reload() }
                                .font(.system(size: 13, weight: .semibold))
                                .padding(.horizontal, 18).padding(.vertical, 9)
                                .background(Color.white.opacity(0.15), in: Capsule())
                            if item.lines.count > 1 {
                                Button("换线路") { switchLine() }
                                    .font(.system(size: 13, weight: .semibold))
                                    .padding(.horizontal, 18).padding(.vertical, 9)
                                    .background(Color.white.opacity(0.15), in: Capsule())
                            }
                        }
                        .foregroundColor(.white)
                    }
                }

                if showChrome {
                    chrome(landscape: landscape, size: geo.size)
                        .transition(.opacity)
                }

                if let hud = hud {
                    Text(hud)
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.black.opacity(0.6), in: Capsule())
                        .transition(.opacity)
                }
            }
            .statusBarHidden(!showChrome)
            .persistentSystemOverlays(.hidden)
        }
        .background(Color.black)
        .onAppear {
            OrientationManager.shared.allowLandscape = true
            SystemVolume.shared.attach()
            engine.activateAudio()
            loadCurrent()
        }
        .onDisappear {
            saveProgress()
            engine.pause()
            MPNowPlayingInfoCenter.default().nowPlayingInfo = nil
            OrientationManager.shared.allowLandscape = false
            OrientationManager.shared.lockPortrait()
        }
        .onReceive(ticker) { _ in
            saveProgress()
            updateNowPlaying()
        }
        .sheet(isPresented: $showEpisodes) {
            episodeSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    // MARK: - 控制层

    private func chrome(landscape: Bool, size: CGSize) -> some View {
        VStack {
            HStack(alignment: .center, spacing: 12) {
                Button { dismiss() } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(Color.black.opacity(0.35), in: Circle())
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(item.name)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .lineLimit(1)
                    Text(currentEpisode?.name ?? "")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundColor(.white.opacity(0.6))
                        .lineLimit(1)
                }
                Spacer()
                if item.lines.count > 1 {
                    Text(currentLineName)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.14), in: Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 6)

            Spacer()

            HStack(spacing: 40) {
                Button { engine.skip(-10) } label: {
                    Image(systemName: "gobackward.10")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(.white)
                }
                Button {
                    engine.toggle()
                    scheduleHide()
                } label: {
                    Image(systemName: engine.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 30, weight: .black))
                        .foregroundColor(.white)
                        .frame(width: 62, height: 62)
                        .background(Color.white.opacity(0.14), in: Circle())
                }
                Button { engine.skip(10) } label: {
                    Image(systemName: "goforward.10")
                        .font(.system(size: 25, weight: .regular))
                        .foregroundColor(.white)
                }
            }

            Spacer()

            VStack(spacing: 10) {
                progressBar

                HStack(spacing: 18) {
                    Menu {
                        ForEach([0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { r in
                            Button {
                                engine.setRate(Float(r))
                            } label: {
                                Text(r == 1.0 ? "正常" : "\(String(format: "%g", r))x")
                            }
                        }
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "speedometer").font(.system(size: 12, weight: .semibold))
                            Text(engine.rate == 1 ? "倍速" : String(format: "%gx", engine.rate))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                        }
                        .foregroundColor(.white.opacity(0.85))
                    }

                    if item.lines.count > 1 {
                        Menu {
                            ForEach(Array(item.lines.enumerated()), id: \.offset) { idx, line in
                                Button {
                                    switchLine(to: idx)
                                } label: {
                                    Text(line.name + "（\(line.episodes.count)集）")
                                }
                            }
                        } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "arrow.triangle.branch").font(.system(size: 12, weight: .semibold))
                                Text("线路").font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    if episodes.count > 1 {
                        Button { showEpisodes = true } label: {
                            HStack(spacing: 3) {
                                Image(systemName: "list.bullet").font(.system(size: 12, weight: .semibold))
                                Text("选集").font(.system(size: 11, weight: .semibold, design: .rounded))
                            }
                            .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    if pip.available {
                        Button { pip.toggle() } label: {
                            Image(systemName: "pip.enter")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(.white.opacity(0.85))
                        }
                    }

                    Spacer()

                    Button { toggleOrientation() } label: {
                        Image(systemName: landscape ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.white.opacity(0.85))
                    }
                }
                .padding(.horizontal, 2)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, landscape ? 12 : 22)
        }
        .background(
            LinearGradient(colors: [.black.opacity(0.65), .clear, .clear, .black.opacity(0.75)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        )
    }

    private var progressBar: some View {
        VStack(spacing: 5) {
            GeometryReader { geo in
                let total = max(engine.duration, 1)
                let value = dragSeek ?? engine.time
                let ratio = min(1, max(0, value / total))
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.22))
                        .frame(height: 3)
                    Capsule()
                        .fill(Theme.accentGradient)
                        .frame(width: max(2, geo.size.width * ratio), height: 3)
                    Circle()
                        .fill(Color.white)
                        .frame(width: dragSeek == nil ? 9 : 15, height: dragSeek == nil ? 9 : 15)
                        .offset(x: max(0, min(geo.size.width - 9, geo.size.width * ratio - 4.5)))
                }
                .frame(width: geo.size.width, height: 20, alignment: .leading)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { v in
                            let r = min(1, max(0, v.location.x / geo.size.width))
                            dragSeek = r * total
                        }
                        .onEnded { _ in
                            if let t = dragSeek { engine.seek(to: t) }
                            dragSeek = nil
                            scheduleHide()
                        }
                )
            }
            .frame(height: 20)

            HStack {
                Text((dragSeek ?? engine.time).timeText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.75))
                Spacer()
                Text(engine.duration.timeText)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.55))
            }
        }
    }

    // MARK: - 手势

    private func dragGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 14)
            .onChanged { v in
                if dragMode == .none {
                    let horizontal = abs(v.translation.width) > abs(v.translation.height) * 1.4
                    if horizontal {
                        dragMode = .seek
                        dragStartTime = engine.time
                    } else {
                        if v.startLocation.x < width / 2 {
                            dragMode = .brightness
                            startBrightness = UIScreen.main.brightness
                        } else {
                            dragMode = .volume
                            startVolume = SystemVolume.shared.value
                        }
                    }
                }

                switch dragMode {
                case .seek:
                    let delta = Double(v.translation.width) / Double(max(width, 1)) * max(engine.duration, 60) * 1.2
                    let target = max(0, min(engine.duration > 0 ? engine.duration : delta, dragStartTime + delta))
                    dragSeek = target
                    hud = "\(target.timeText) / \(engine.duration.timeText)"
                case .brightness:
                    let delta = -v.translation.height / 220
                    let value = min(1, max(0, startBrightness + delta))
                    UIScreen.main.brightness = value
                    hud = "亮度 \(Int(value * 100))%"
                case .volume:
                    let delta = Float(-v.translation.height / 220)
                    let value = min(1, max(0, startVolume + delta))
                    SystemVolume.shared.value = value
                    hud = "音量 \(Int(value * 100))%"
                case .none:
                    break
                }
            }
            .onEnded { _ in
                if dragMode == .seek, let t = dragSeek {
                    engine.seek(to: t)
                }
                dragMode = .none
                dragSeek = nil
                withAnimation(.easeOut(duration: 0.25)) { hud = nil }
                scheduleHide()
            }
    }

    private func scheduleHide() {
        showChrome = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
            if engine.isPlaying {
                withAnimation(.easeOut(duration: 0.25)) { showChrome = false }
            }
        }
    }

    // MARK: - 选集面板

    private var episodeSheet: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("选集")
                        .font(.system(size: 17, weight: .heavy, design: .rounded))
                        .foregroundColor(Theme.text)
                    Text(item.lines[lineIndex].name)
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textFaint)
                    Spacer()
                    Button { showEpisodes = false } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(Theme.textDim)
                            .frame(width: 28, height: 28)
                            .background(Color.white.opacity(0.08), in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 16)

                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                        ForEach(episodes) { ep in
                            Button {
                                showEpisodes = false
                                switchEpisode(to: ep.index)
                            } label: {
                                Text(ep.name.count > 8 ? "第\(ep.index + 1)集" : ep.name)
                                    .font(.system(size: 11.5, weight: .semibold, design: .rounded))
                                    .foregroundColor(ep.index == episodeIndex ? .black : Theme.textDim)
                                    .lineLimit(1)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 9)
                                    .background(
                                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                                            .fill(ep.index == episodeIndex ? Color.white.opacity(0.9) : Color.white.opacity(0.055))
                                    )
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    // MARK: - 播放控制

    private func loadCurrent() {
        guard let ep = currentEpisode, let url = URL(string: ep.url) else {
            engine.failed = "这一集没有可用的播放地址"
            return
        }
        var start: Double = 0
        if rememberProgress,
           let pos = library.resumePosition(item: item, lineIndex: lineIndex, episodeIndex: episodeIndex) {
            start = pos
        }
        engine.onEnd = autoPlayNext ? { nextEpisode() } : nil
        engine.onNext = { nextEpisode() }
        engine.configureRemoteCommands()
        engine.load(url: url, startAt: start)
        updateNowPlaying()
    }

    private func reload() { loadCurrent() }

    private func switchEpisode(to index: Int) {
        saveProgress()
        episodeIndex = min(max(0, index), max(0, episodes.count - 1))
        loadCurrent()
    }

    private func nextEpisode() {
        guard episodeIndex + 1 < episodes.count else {
            saveProgress(final: true)
            showChrome = true
            return
        }
        switchEpisode(to: episodeIndex + 1)
    }

    private func switchLine(to index: Int? = nil) {
        saveProgress()
        let target = index ?? (lineIndex + 1) % max(item.lines.count, 1)
        lineIndex = min(max(0, target), item.lines.count - 1)
        if episodeIndex >= episodes.count { episodeIndex = 0 }
        loadCurrent()
    }

    private func saveProgress(final: Bool = false) {
        guard rememberProgress, engine.duration > 0 else { return }
        let pos = final ? engine.duration : engine.time
        guard pos > 3 else { return }
        library.update(item: item, lineIndex: lineIndex, episodeIndex: episodeIndex,
                       position: pos, duration: engine.duration)
    }

    private func updateNowPlaying() {
        guard engine.duration > 0 else { return }
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: item.name,
            MPMediaItemPropertyArtist: currentEpisode?.name ?? "VidHub",
            MPMediaItemPropertyPlaybackDuration: engine.duration,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: engine.time,
            MPNowPlayingInfoPropertyPlaybackRate: engine.isPlaying ? 1.0 : 0.0,
        ]
        if let url = currentEpisode?.url, let u = URL(string: url) {
            info[MPMediaItemPropertyAssetURL] = u
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func toggleOrientation() {
        let scene = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }.first
        guard let scene = scene else { return }
        let isLandscape = scene.interfaceOrientation.isLandscape
        scene.requestGeometryUpdate(.iOS(interfaceOrientations: isLandscape ? .portrait : .landscapeRight))
    }
}
