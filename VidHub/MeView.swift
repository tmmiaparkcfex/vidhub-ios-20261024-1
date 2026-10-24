import SwiftUI

struct MeView: View {
    @EnvironmentObject private var model: AppModel
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var asSheet: Bool = false

    @State private var showAdd = false
    @State private var showFavorites = false
    @State private var showHistory = false
    @AppStorage("vidhub.autoplay") private var autoPlayNext = true
    @AppStorage("vidhub.remember") private var rememberProgress = true

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 16) {
                        profileCard
                        sourceSection
                        settingsSection
                        aboutSection
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .padding(.bottom, 24)
                }
            }
            .navigationTitle("我的")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                if asSheet {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("完成") { dismiss() }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(Theme.accent)
                    }
                }
            }
            .sheet(isPresented: $showAdd) {
                AddSourceSheet()
            }
            .sheet(isPresented: $showFavorites) {
                CollectionSheet(title: "收藏", items: library.favorites, empty: "还没有收藏的片子")
            }
            .sheet(isPresented: $showHistory) {
                HistorySheet()
            }
        }
    }

    private var profileCard: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Theme.accentGradient)
                    .frame(width: 52, height: 52)
                Image(systemName: "play.fill")
                    .font(.system(size: 19, weight: .black))
                    .foregroundColor(.black.opacity(0.85))
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("VidHub")
                    .font(.system(size: 17, weight: .heavy, design: .rounded))
                    .foregroundColor(Theme.text)
                Text("\(model.enabledSources.count) 个已启用接口 · \(library.favorites.count) 部收藏")
                    .font(.system(size: 11))
                    .foregroundColor(Theme.textFaint)
            }
            Spacer()
        }
        .padding(14)
        .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 0.8)
        )
    }

    // MARK: - 接口

    private var sourceSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("接口")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(Theme.text)
                Spacer()
                Button {
                    showAdd = true
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                        Text("添加").font(.system(size: 11.5, weight: .semibold))
                    }
                    .foregroundColor(Theme.accent)
                }
            }
            .padding(.horizontal, 4)

            VStack(spacing: 0) {
                ForEach(model.sources) { source in
                    sourceRow(source)
                    if source.id != model.sources.last?.id {
                        Divider().background(Theme.stroke).padding(.leading, 14)
                    }
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 0.8)
            )
        }
    }

    private func sourceRow(_ source: MediaSource) -> some View {
        HStack(spacing: 11) {
            Button {
                model.setActive(source.id)
            } label: {
                ZStack {
                    Circle()
                        .stroke(source.id == model.activeSourceID ? Theme.accent : Theme.stroke, lineWidth: 1.4)
                        .frame(width: 19, height: 19)
                    if source.id == model.activeSourceID {
                        Circle().fill(Theme.accent).frame(width: 11, height: 11)
                    }
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(source.name)
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundColor(source.enabled ? Theme.text : Theme.textFaint)
                        .lineLimit(1)
                    if source.isDemo {
                        TagPill(text: "演示", tint: Theme.accentSoft, textColor: Theme.accent)
                    }
                }
                Text(source.isDemo ? "内置数据，不联网" : source.api)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textFaint)
                    .lineLimit(1)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { source.enabled },
                set: { _ in model.toggleSource(source.id) }
            ))
            .labelsHidden()
            .tint(Theme.accent)
            .scaleEffect(0.8)

            Menu {
                Button("设为当前源") { model.setActive(source.id) }
                if !source.isDemo {
                    Button("删除接口", role: .destructive) { model.deleteSource(source.id) }
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(Theme.textFaint)
                    .frame(width: 24, height: 28)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 11)
    }

    // MARK: - 设置

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("播放与记录")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                toggleRow("播完自动下一集", isOn: $autoPlayNext, icon: "forward.end.fill")
                Divider().background(Theme.stroke).padding(.leading, 14)
                toggleRow("记住播放进度", isOn: $rememberProgress, icon: "clock.arrow.circlepath")
                Divider().background(Theme.stroke).padding(.leading, 14)
                actionRow("收藏（\(library.favorites.count)）", icon: "heart.fill") { showFavorites = true }
                Divider().background(Theme.stroke).padding(.leading, 14)
                actionRow("观看历史（\(library.history.count)）", icon: "clock.fill") { showHistory = true }
                Divider().background(Theme.stroke).padding(.leading, 14)
                actionRow("清空观看历史", icon: "trash.fill", tint: Color(red: 0.95, green: 0.35, blue: 0.4)) {
                    library.clearHistory()
                }
            }
            .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 0.8)
            )
        }
    }

    private func toggleRow(_ title: String, isOn: Binding<Bool>, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(Theme.textDim)
                .frame(width: 20)
            Text(title)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Theme.accent)
                .scaleEffect(0.8)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private func actionRow(_ title: String, icon: String, tint: Color = Theme.text, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 11) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(tint == Theme.text ? Theme.textDim : tint)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                    .foregroundColor(tint)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textFaint.opacity(0.6))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 13)
        }
        .buttonStyle(.plain)
    }

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("关于")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(Theme.text)
                .padding(.horizontal, 4)
            Text("VidHub 1.0.0 · 原生 SwiftUI\n数据来自你自己添加的采集接口，本 App 不内置任何影视资源。\n播放基于系统 AVPlayer，HLS / mp4 直连播放，不做转码。")
                .font(.system(size: 10.5))
                .foregroundColor(Theme.textFaint)
                .lineSpacing(3)
                .padding(14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.surface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous).stroke(Theme.stroke, lineWidth: 0.8)
                )
        }
    }
}

// MARK: - 添加接口

struct AddSourceSheet: View {
    @EnvironmentObject private var model: AppModel
    @Environment(\.dismiss) private var dismiss

    @State private var mode = 0
    @State private var name = ""
    @State private var api = ""
    @State private var tvboxText = ""
    @State private var status: String?
    @State private var testing = false
    @State private var ok = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Picker("", selection: $mode) {
                            Text("采集接口").tag(0)
                            Text("TVBox 配置").tag(1)
                        }
                        .pickerStyle(.segmented)

                        if mode == 0 {
                            field("名称", text: $name, hint: "例如：主源")
                            field("接口地址", text: $api, hint: "https://example.com/api.php/provide/vod/")
                            Text("支持苹果CMS V10 / TVBox 采集接口，填到 provide/vod/ 这一层，末尾斜杠可有可无。")
                                .font(.system(size: 10.5))
                                .foregroundColor(Theme.textFaint)
                        } else {
                            Text("把 TVBox 配置里的 JSON 内容粘贴进来，会自动挑出所有 CMS 采集接口。")
                                .font(.system(size: 11))
                                .foregroundColor(Theme.textDim)
                            TextEditor(text: $tvboxText)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(Theme.text)
                                .scrollContentBackground(.hidden)
                                .frame(height: 200)
                                .padding(8)
                                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        }

                        if let status = status {
                            HStack(spacing: 5) {
                                Image(systemName: ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                                Text(status).lineLimit(3)
                            }
                            .font(.system(size: 11.5, weight: .medium))
                            .foregroundColor(ok ? Color(red: 0.4, green: 0.85, blue: 0.6) : Theme.gold)
                        }

                        HStack(spacing: 10) {
                            Button {
                                Task { await test() }
                            } label: {
                                HStack(spacing: 5) {
                                    if testing { ProgressView().tint(Theme.text).scaleEffect(0.7) }
                                    Text(testing ? "测试中" : "测试连接")
                                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                                }
                                .foregroundColor(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 11)
                                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }

                            Button {
                                Task { await save() }
                            } label: {
                                Text("保存")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundColor(.black)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 11)
                                    .background(Color.white.opacity(0.92), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                            }
                        }
                    }
                    .padding(16)
                }
            }
            .navigationTitle("添加接口")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("取消") { dismiss() }.foregroundColor(Theme.textDim)
                }
            }
        }
    }

    private func field(_ title: String, text: Binding<String>, hint: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textDim)
            TextField(hint, text: text)
                .font(.system(size: 13))
                .foregroundColor(Theme.text)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .keyboardType(.URL)
                .padding(11)
                .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        }
    }

    private func normalized(_ raw: String) -> String {
        let t = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var comps = URLComponents(string: t) else { return t }
        if !comps.path.hasSuffix("/") { comps.path += "/" }
        return comps.string ?? t
    }

    private func test() async {
        testing = true
        status = nil
        defer { testing = false }
        if mode == 1 {
            do {
                let list = try await parseTVBox()
                ok = true
                status = "识别到 \(list.count) 个接口"
            } catch {
                ok = false
                status = error.localizedDescription
            }
            return
        }
        do {
            let count = try await CMSClient.shared.probe(normalized(api))
            ok = true
            status = "连接成功，首页返回 \(count) 条"
        } catch {
            ok = false
            status = error.localizedDescription
        }
    }

    private func parseTVBox() async throws -> [MediaSource] {
        let raw = tvboxText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { throw CMSError.tvboxParse }
        if raw.lowercased().hasPrefix("http"), let json = try? await CMSClient.shared.loadTVBoxConfig(url: raw) {
            return json
        }
        guard let obj = CMSClient.jsonObject(from: raw) else { throw CMSError.tvboxParse }
        return try CMSClient.shared.sources(fromTVBoxJSON: obj)
    }

    private func save() async {
        if mode == 1 {
            do {
                let list = try await parseTVBox()
                model.addSources(list)
                dismiss()
            } catch {
                ok = false
                status = error.localizedDescription
            }
            return
        }
        let url = normalized(api)
        guard url.lowercased().hasPrefix("http") else {
            ok = false
            status = "接口地址需要以 http:// 或 https:// 开头"
            return
        }
        model.addSource(name: name, api: url)
        dismiss()
    }
}

// MARK: - 收藏 / 历史

struct CollectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    let items: [MediaItem]
    let empty: String

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if items.isEmpty {
                    EmptyStateView(icon: "heart", title: empty)
                } else {
                    ScrollView {
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 16) {
                            ForEach(items) { item in
                                NavigationLink(value: item) {
                                    MediaCard(item: item, width: 100)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(16)
                    }
                    .navigationDestination(for: MediaItem.self) { DetailView(item: $0) }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(Theme.textDim)
                }
            }
        }
    }
}

struct HistorySheet: View {
    @EnvironmentObject private var library: LibraryStore
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                if library.history.isEmpty {
                    EmptyStateView(icon: "clock", title: "还没有观看记录")
                } else {
                    ScrollView {
                        VStack(spacing: 0) {
                            ForEach(library.history) { record in
                                HStack(spacing: 11) {
                                    PosterImage(url: record.item.posterURL, title: record.item.name)
                                        .frame(width: 54, height: 76)
                                        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.item.name)
                                            .font(.system(size: 13, weight: .semibold, design: .rounded))
                                            .foregroundColor(Theme.text)
                                            .lineLimit(1)
                                        Text(record.episodeName + " · 看到 " + record.position.timeText)
                                            .font(.system(size: 10.5))
                                            .foregroundColor(Theme.textFaint)
                                        GeometryReader { geo in
                                            ZStack(alignment: .leading) {
                                                Capsule().fill(Color.white.opacity(0.12))
                                                Capsule().fill(Theme.accentGradient)
                                                    .frame(width: max(2, geo.size.width * record.progress))
                                            }
                                        }
                                        .frame(height: 3)
                                        .padding(.trailing, 30)
                                    }
                                    Spacer()
                                    Button {
                                        library.remove(record)
                                    } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(Theme.textFaint)
                                            .frame(width: 24, height: 24)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                Divider().background(Theme.stroke).padding(.leading, 81)
                            }
                        }
                        .padding(.top, 6)
                    }
                }
            }
            .navigationTitle("观看历史")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.bg, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("关闭") { dismiss() }.foregroundColor(Theme.textDim)
                }
            }
        }
    }
}
