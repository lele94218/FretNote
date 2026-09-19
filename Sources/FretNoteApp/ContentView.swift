import SwiftUI
import FretNoteCore

struct ContentView: View {
    @EnvironmentObject private var appearance: AppearancePreferences
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme, contrast: contrast) }
    private var ink: Color { palette.ink }
    private var muted: Color { palette.muted }
    private var rule: Color { palette.rule }
    @ObservedObject var audio: AudioInput
    @ObservedObject var practice: PracticeStore
    @State private var showProgress = false
    @State private var showError = false
    var body: some View {
        HSplitView {
            if appearance.sidebarVisible {
                sidebar
                    .frame(minWidth: 250, idealWidth: 270, maxWidth: 330)
            }
            VStack(spacing: 0) {
                header.padding(.horizontal, 24).padding(.vertical, 16)
                rule.frame(height: 1)
                actionBar.padding(.horizontal, 24).padding(.vertical, 12)
                if audio.running {
                    HStack {
                        Text(audio.reading.map { "听到 \(GuitarNote.names[($0.midi % 12 + 12) % 12])\($0.midi / 12 - 1)" } ?? "等待清晰的单音")
                        Spacer()
                        Text(audio.level > 0.8 ? "电平过高，请降低声卡增益" : (audio.level > 0 ? String(format: "输入 %.0f dB", 20 * log10(audio.level)) : "暂无输入信号"))
                    }.font(.system(size: 12 * scale)).foregroundStyle(muted)
                        .padding(.horizontal, 24).padding(.bottom, 12)
                }
                rule.frame(height: 1)
                exercise.padding(.horizontal, 20).padding(.vertical, 12)
                rule.frame(height: 1)
                HStack {
                    Text("首次正确 \(practice.accuracy) · 平均 \(practice.averageTime)")
                        .foregroundStyle(muted)
                    Spacer()
                    if audio.error != nil || practice.persistenceError != nil {
                        Button { showError = true } label: { Label("查看问题", systemImage: "exclamationmark.circle") }
                    }
                    Button("学习记录") { showProgress = true }
                }.font(.system(size: 12 * scale)).buttonStyle(.bordered)
                    .padding(.horizontal, 20).padding(.vertical, 12)
            }.frame(minWidth: 600)
        }
        .background(palette.background)
        .foregroundStyle(ink)
        .font(.system(size: 13 * scale))
        .tint(ink)
        .onChange(of: practice.feedback) { message in
            guard NSWorkspace.shared.isVoiceOverEnabled else { return }
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        .sheet(isPresented: $showProgress) {
            VStack(spacing: 20) {
                progressPanel
                Button("完成") { showProgress = false }.keyboardShortcut(.defaultAction)
            }.padding(24).frame(width: 440 * scale)
                .foregroundStyle(ink).background(palette.background)
                .preferredColorScheme(appearance.theme.colorScheme)
        }
        .alert("需要处理的问题", isPresented: $showError) {
            Button("知道了", role: .cancel) {}
        } message: {
            Text([audio.error, practice.persistenceError].compactMap { $0 }.joined(separator: "\n\n"))
        }
        .sheet(isPresented: $practice.showSummary) {
            summary.preferredColorScheme(appearance.theme.colorScheme)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("练习")
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        practice.mode = mode
                        practice.notes = []
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.rawValue).font(.system(size: 14 * scale, weight: .medium))
                            Spacer()
                            if practice.mode == mode { Text("—") }
                        }.padding(.vertical, 7).foregroundStyle(practice.mode == mode ? ink : muted)
                            .padding(.horizontal, 8)
                            .background(practice.mode == mode ? palette.selection : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(practice.active)
                    .accessibilityAddTraits(practice.mode == mode ? [.isSelected] : [])
                }
            }
            VStack(alignment: .leading, spacing: 12) {
                eyebrow("练习范围")
                if practice.mode == .names {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("琴弦 · 可多选").foregroundStyle(muted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(1...6, id: \.self) { number in
                                Toggle(isOn: Binding(
                                    get: { practice.selectedStrings.contains(number) },
                                    set: { practice.setString(number, selected: $0) }
                                )) {
                                    Text("\(number)").frame(maxWidth: .infinity)
                                }.toggleStyle(.button)
                                    .accessibilityLabel("第 \(number) 弦")
                                    .help("选择要练习的琴弦，至少保留一根")
                            }
                        }
                    }
                }
                if practice.mode != .names {
                VStack(spacing: 12) {
                    HStack { Text("起始品"); Spacer(); ScaledPicker(accessibilityName: "起始品", controlWidth: 72, selection: $practice.lowerFret, options: Array((practice.customRange ? 0 : 1)...(practice.customRange ? PracticeStore.maximumFret : PracticeStore.maximumFret - 3))) { "\($0)" }.accessibilityLabel("起始品") }
                    if practice.customRange {
                        HStack { Text("结束品"); Spacer(); ScaledPicker(accessibilityName: "结束品", controlWidth: 72, selection: $practice.upperFret, options: Array(practice.lowerFret...min(PracticeStore.maximumFret, practice.lowerFret + 5))) { "\($0)" }.accessibilityLabel("结束品") }
                    } else {
                        Text("第 \(practice.lowerFret)–\(practice.upperFret) 品 · 四个品格")
                            .foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Toggle("自定义范围", isOn: $practice.customRange).toggleStyle(.checkbox)
                }
                Toggle("只练自然音", isOn: $practice.naturalsOnly).toggleStyle(.checkbox).controlSize(.large)
                if practice.mode != .names {
                    Toggle("显示音名辅助", isOn: $practice.showNames).toggleStyle(.checkbox).controlSize(.large)
                }
                if practice.mode == .melody {
                    ScaledPicker(title: "旋律长度", selection: $practice.melodyLength, options: Array(3...5)) { "\($0) 个音" }
                }
            }.font(.system(size: 12 * scale)).disabled(practice.active)
            Spacer()
            Text("单音 · 标准调弦")
                .help("单音练习，不考核节奏。请按指定弦与把位弹奏；音高识别无法验证实际弦位。")
                .font(.system(size: 12 * scale)).foregroundStyle(muted).lineSpacing(5)
        }.padding(20)
    }
    private var header: some View {
        HStack(spacing: 16) {
            Button { appearance.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                .accessibilityLabel(appearance.sidebarVisible ? "隐藏侧栏" : "显示侧栏")
                .help("显示或隐藏侧栏（⌃⌘S）")
            Text(practice.mode.rawValue).font(.system(size: 20 * scale, weight: .medium))
            Spacer()
            OpenSettingsButton()
        }.buttonStyle(.bordered)
    }
    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { listeningControls; Spacer(); practiceControls }
            VStack(alignment: .leading, spacing: 12) {
                listeningControls
                HStack { Spacer(); practiceControls }
            }
        }.font(.system(size: 12 * scale)).controlSize(.large).buttonStyle(.bordered)
    }
    private var listeningControls: some View {
        HStack(spacing: 10) {
            Button(audio.starting ? "正在启动…" : (audio.running ? "停止监听" : "开启输入")) {
                if audio.running { audio.stop() } else { Task { await audio.start() } }
            }.disabled(audio.starting || audio.devices.isEmpty)
            Text(audio.running ? "正在监听" : "输入未开启").foregroundStyle(muted)
        }.fixedSize()
    }
    private var practiceControls: some View {
        HStack(spacing: 10) {
            if practice.active {
                Button("提示位置") { practice.reveal() }.disabled(practice.completed)
                Button("跳过") { practice.skip() }.disabled(practice.completed)
                Button("结束练习") { practice.end() }
            } else {
                Button("开始练习") { practice.start() }
                    .buttonStyle(.borderedProminent).disabled(!audio.running)
                    .help(audio.running ? "开始一组 20 个音的练习（⌘Return）" : "先点击左侧“开启输入”")
            }
        }.fixedSize()
    }
    private var exercise: some View {
        VStack(spacing: 12) {
            HStack {
                Text(practice.mode == .names ? "\(practice.notes.isEmpty ? practice.selectedStringLabel : "第 \(practice.currentString) 弦") · 全弦找音" : "第 \(practice.lowerFret)–\(practice.upperFret) 品 · 六根弦")
                Spacer()
                Text("\(practice.answered) / 20 音").monospacedDigit()
            }.font(.system(size: 12 * scale)).foregroundStyle(muted)
            GeometryReader { space in
                let showsBoard = practice.mode != .names || practice.hint
                let gap: CGFloat = 12
                let notationHeight = showsBoard ? (space.size.height - gap) * 0.53 : space.size.height
                VStack(spacing: gap) {
                    notation.frame(height: notationHeight)
                    if showsBoard {
                        FretboardView(lower: practice.mode == .names ? max(0, (practice.target?.fret ?? 1) - 1) : practice.lowerFret,
                                      upper: practice.mode == .names ? min(PracticeStore.maximumFret, (practice.target?.fret ?? 1) + 2) : practice.upperFret,
                                      highlightedNote: practice.hint ? practice.target : nil,
                                      emphasizedString: practice.mode == .names ? practice.currentString : nil)
                            .frame(height: max(0, space.size.height - notationHeight - gap))
                    }
                }
            }
            HStack(spacing: 8) {
                if practice.feedbackKind != 0 {
                    Image(systemName: practice.feedbackKind > 0 ? "checkmark" : "xmark")
                }
                Text(practice.notes.isEmpty ? "开启输入后，点击开始练习。" : practice.feedback)
            }.font(.system(size: 13 * scale))
                .foregroundStyle(practice.feedbackKind == 0 ? muted : ink)
                .frame(minHeight: 22 * scale)
        }
    }
    private var notation: some View {
        Group {
            if practice.notes.isEmpty {
                VStack(spacing: 12) {
                    Text("准备练习").font(.system(size: 24 * scale))
                    Text("每组 20 个音").font(.system(size: 13 * scale)).foregroundStyle(muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if practice.mode == .names {
                VStack(spacing: 8) {
                    Text(practice.completed ? "完成" : "弹出这个音").font(.system(size: 13 * scale)).foregroundStyle(muted)
                    Text((practice.target ?? practice.notes.last)?.name ?? "—")
                        .font(.system(size: 72 * scale)).minimumScaleFactor(0.5)
                    Text("第 \(practice.currentString) 弦").font(.system(size: 14 * scale)).foregroundStyle(muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                StaffView(notes: practice.notes, current: practice.index, showNames: practice.showNames)
            }
        }
    }
    private var progressPanel: some View {
        VStack(alignment: .leading, spacing: 17) {
            eyebrow("学习记录")
            HStack {
                metric(practice.accuracy, caption: "本组首次正确")
                Spacer()
                metric(practice.averageTime, caption: "平均找音时间")
            }
            rule.frame(height: 1)
            Text("优先复习").font(.system(size: 12 * scale, weight: .medium))
            if practice.weakNotes.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12 * scale)).foregroundStyle(muted).lineSpacing(5)
            } else {
                ForEach(Array(practice.weakNotes.prefix(3)), id: \.note.id) { item in
                    HStack {
                        Text("\(item.note.string) 弦 · \(item.note.name)")
                        Spacer()
                        Text("\(Int(item.score.accuracy * 100))%").foregroundStyle(muted).monospacedDigit()
                    }.font(.system(size: 12 * scale))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var summary: some View {
        VStack(spacing: 24) {
            Text("练习结束").font(.system(size: 24 * scale, weight: .medium))
            Text("已完成 \(practice.answered) 个音，学习记录已更新。") .foregroundStyle(muted)
            HStack(spacing: 36) {
                metric(practice.accuracy, caption: "首次正确率")
                metric(practice.averageTime, caption: "平均找音时间")
            }
            Text("用过提示或跳过的音会优先安排复习。") .font(.system(size: 12 * scale)).foregroundStyle(muted)
            Button("完成") { practice.showSummary = false }.buttonStyle(.borderedProminent).keyboardShortcut(.defaultAction)
        }.padding(42).frame(width: 480 * scale).foregroundStyle(ink).background(palette.background)
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 12 * scale, weight: .medium)).foregroundStyle(muted) }
    private func metric(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 24 * scale, weight: .regular)).monospacedDigit()
            Text(caption).font(.system(size: 12 * scale)).foregroundStyle(muted)
        }
    }
}


/// AppKit pop-up menus provide standard selection, keyboard navigation and dismissal.
struct ScaledPicker<Value: Hashable>: View {
    var title: String? = nil
    var accessibilityName: String? = nil
    var controlWidth: CGFloat? = nil
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    @Environment(\.interfaceScale) private var scale
    var body: some View {
        HStack(spacing: 8) {
            if let title { Text(title).fixedSize() }
            NativeChoicePicker(selection: $selection, options: options, label: label, accessibilityTitle: accessibilityName ?? title ?? label(selection), controlWidth: controlWidth)
                .fixedSize()
                .accessibilityLabel(title ?? label(selection))
        }
        .font(.system(size: 12 * scale))
    }
}

struct OpenSettingsButton: View {
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink { Image(systemName: "gearshape") }
            } else {
                Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: {
                    Image(systemName: "gearshape")
                }
            }
        }.accessibilityLabel("设置").help("设置（⌘,）")
    }
}
