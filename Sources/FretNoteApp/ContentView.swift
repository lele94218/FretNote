import SwiftUI
import FretNoteCore

struct ContentView: View, Localizable {
    @Environment(\.appLanguage) var language
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
    @StateObject private var learningStore = LearningStore()
    @StateObject private var shapePractice = ShapePracticeStore()
    @StateObject private var scoreWorkspace = GuitarProWorkspace()
    @State private var restoredNavigation = false
    @State private var showProgress = false
    @State private var showFullFretboard = false
    @State private var showError = false
    var body: some View {
        Group {
            if practice.scorePlayback { scoreBody }
            else if practice.learning {
                LearningView(store: learningStore, practice: practice, audio: audio, drill: shapePractice, workspace: scoreWorkspace)
            } else { practiceBody }
        }
        .sheet(isPresented: $showFullFretboard) { PracticeFretboardSheet(practice: practice, workspace: scoreWorkspace) }
        .onChange(of: practice.scorePlayback) { UserDefaults.standard.set($0, forKey: "scorePlaybackTab") }
        .onAppear {
            if !restoredNavigation {
                practice.scorePlayback = UserDefaults.standard.bool(forKey: "scorePlaybackTab")
                restoredNavigation = true
            }
            audio.onNote = { midi in
                if practice.learning { shapePractice.receive(note: midi, records: practice) }
                else { practice.receive(midi) }
            }
            audio.onChord = { midis in
                if practice.learning { shapePractice.receive(chord: midis, records: practice) }
            }
            audio.onLevel = { rms in shapePractice.observeLevel(rms, gate: pow(10, audio.gateDB / 20)) }
        }
        .onChange(of: audio.running) { running in
            if !running && shapePractice.active { shapePractice.end(records: practice) }
        }
    }
    private var scoreBody: some View {
        HSplitView {
            if appearance.sidebarVisible {
                VStack(alignment: .leading) {
                    ExerciseNavigation(practice: practice, audio: audio, learning: learningStore, drill: shapePractice)
                    Spacer()
                }.padding(20).frame(minWidth: 250, idealWidth: 270, maxWidth: 330)
            }
            VStack(spacing: 0) {
                HStack {
                    Button { appearance.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                        .accessibilityLabel(L("显示或隐藏侧栏"))
                    Text(L("指板跟谱")).font(.editorial(size: 20 * scale))
                    Spacer()
                    OpenSettingsButton()
                }.buttonStyle(EditorialButtonStyle()).padding(.horizontal, 24).padding(.top, 16)
                FullFretboardView(embedded: true, workspace: scoreWorkspace)
            }.frame(minWidth: 600)
        }.foregroundStyle(ink).background(palette.background)
    }
    private var practiceBody: some View {
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
                        Text(L(audio.reading.map { L("听到 \(GuitarNote.names[($0.midi % 12 + 12) % 12])\($0.midi / 12 - 1)") } ?? L("等待清晰的单音")))
                        Spacer()
                        Text(L(audio.level > 0.8 ? L("电平过高，请降低声卡增益") : (audio.level > 0 ? String(format: L("输入 %.0f dB"), 20 * log10(audio.level)) : L("暂无输入信号"))))
                    }.font(.editorial(size: 12 * scale)).foregroundStyle(muted)
                        .padding(.horizontal, 24).padding(.bottom, 12)
                }
                rule.frame(height: 1)
                exercise.padding(.horizontal, 20).padding(.vertical, 12)
                rule.frame(height: 1)
                HStack {
                    Text(L("首次正确 \(practice.accuracy) · 平均 \(practice.averageTime)"))
                        .foregroundStyle(muted)
                    Spacer()
                    if audio.error != nil || practice.persistenceError != nil {
                        Button { showError = true } label: { Label(L("查看问题"), systemImage: "exclamationmark.circle") }
                    }
                    Button(L("学习记录")) { showProgress = true }
                }.font(.editorial(size: 12 * scale)).buttonStyle(EditorialButtonStyle())
                    .padding(.horizontal, 20).padding(.vertical, 12)
            }.frame(minWidth: 600)
        }
        .background(palette.background)
        .foregroundStyle(ink)
        .font(.editorial(size: 13 * scale))
        .tint(ink)
        .onChange(of: practice.feedback) { message in
            guard NSWorkspace.shared.isVoiceOverEnabled else { return }
            NSAccessibility.post(element: NSApplication.shared, notification: .announcementRequested,
                userInfo: [.announcement: message, .priority: NSAccessibilityPriorityLevel.medium.rawValue])
        }
        .sheet(isPresented: $showProgress) {
            LearningHistoryView(practice: practice)
                .preferredColorScheme(appearance.theme.colorScheme)
        }
        .alert(L("需要处理的问题"), isPresented: $showError) {
            Button(L("知道了"), role: .cancel) {}
        } message: {
            Text(L([audio.error, practice.persistenceError].compactMap { $0 }.joined(separator: "\n\n")))
        }
        .sheet(isPresented: $practice.showSummary) {
            summary.preferredColorScheme(appearance.theme.colorScheme)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExerciseNavigation(practice: practice, audio: audio, learning: learningStore, drill: shapePractice)
            VStack(alignment: .leading, spacing: 12) {
                eyebrow(L("练习范围"))
                if practice.mode == .names {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(L("琴弦 · 可多选")).foregroundStyle(muted)
                        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 3), spacing: 8) {
                            ForEach(1...6, id: \.self) { number in
                                Toggle(isOn: Binding(
                                    get: { practice.selectedStrings.contains(number) },
                                    set: { practice.setString(number, selected: $0) }
                                )) {
                                    Text(L("\(number)")).frame(maxWidth: .infinity)
                                }.toggleStyle(.button)
                                    .accessibilityLabel(L("第 \(number) 弦"))
                                    .help(L("选择要练习的琴弦，至少保留一根"))
                            }
                        }
                    }
                }
                if practice.mode != .names {
                VStack(spacing: 12) {
                    HStack { Text(L("起始品")); Spacer(); ScaledPicker(accessibilityName: L("起始品"), controlWidth: 72, selection: $practice.lowerFret, options: Array((practice.customRange ? 0 : 1)...(practice.customRange ? PracticeStore.maximumFret : PracticeStore.maximumFret - 3))) { "\($0)" }.accessibilityLabel(L("起始品")) }
                    if practice.customRange {
                        HStack { Text(L("结束品")); Spacer(); ScaledPicker(accessibilityName: L("结束品"), controlWidth: 72, selection: $practice.upperFret, options: Array(practice.lowerFret...min(PracticeStore.maximumFret, practice.lowerFret + 5))) { "\($0)" }.accessibilityLabel(L("结束品")) }
                    } else {
                        Text(L("第 \(practice.lowerFret)–\(practice.upperFret) 品 · 四个品格"))
                            .foregroundStyle(muted).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                Toggle(L("自定义范围"), isOn: $practice.customRange).toggleStyle(.checkbox)
                }
                Toggle(L("只练自然音"), isOn: $practice.naturalsOnly).toggleStyle(.checkbox).controlSize(.large)
                if practice.mode != .names {
                    Toggle(L("显示音名辅助"), isOn: $practice.showNames).toggleStyle(.checkbox).controlSize(.large)
                }
                if practice.mode == .melody {
                    ScaledPicker(title: L("旋律长度"), selection: $practice.melodyLength, options: Array(3...5)) { L("\($0) 个音") }
                }
            }.font(.editorial(size: 12 * scale)).disabled(practice.active)
            Spacer()
            Text(L("单音 · 标准调弦"))
                .help(L("单音练习，不考核节奏。请按指定弦与把位弹奏；音高识别无法验证实际弦位。"))
                .font(.editorial(size: 12 * scale)).foregroundStyle(muted).lineSpacing(5)
        }.padding(20)
    }
    private var header: some View {
        HStack(spacing: 16) {
            Button { appearance.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                .accessibilityLabel(appearance.sidebarVisible ? L("隐藏侧栏") : L("显示侧栏"))
                .help(L("显示或隐藏侧栏（⌃⌘S）"))
            Text(L(practice.mode.rawValue)).font(.editorial(size: 20 * scale, weight: .regular))
            Spacer()
            Button { showFullFretboard = true } label: { Image(systemName: "guitars") }.help(L("全指板")).accessibilityLabel(L("全指板"))
            OpenSettingsButton()
        }.buttonStyle(EditorialButtonStyle())
    }
    private var actionBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 16) { listeningControls; Spacer(); practiceControls }
            VStack(alignment: .leading, spacing: 12) {
                listeningControls
                HStack { Spacer(); practiceControls }
            }
        }.font(.editorial(size: 12 * scale)).controlSize(.large).buttonStyle(EditorialButtonStyle())
    }
    private var listeningControls: some View {
        HStack(spacing: 10) {
            Button(audio.starting ? L("正在启动…") : (audio.running ? L("停止监听") : L("开启输入"))) {
                if audio.running { audio.stop() } else { Task { await audio.start() } }
            }.disabled(audio.starting || audio.devices.isEmpty)
            Text(L(audio.running ? L("正在监听") : L("输入未开启"))).foregroundStyle(muted)
        }.fixedSize()
    }
    private var practiceControls: some View {
        HStack(spacing: 10) {
            if practice.active {
                Button(L("提示位置")) { practice.reveal() }.disabled(practice.completed)
                Button(L("跳过")) { practice.skip() }.disabled(practice.completed)
                Button(L("结束练习")) { practice.end() }
            } else {
                Button(L("开始练习")) { practice.start() }
                    .buttonStyle(EditorialButtonStyle(prominent: true)).disabled(!audio.running)
                    .help(audio.running ? L("开始一组 20 个音的练习（⌘Return）") : L("先点击左侧“开启输入”"))
            }
        }.fixedSize()
    }
    private var exercise: some View {
        VStack(spacing: 12) {
            HStack {
                Text(L(practice.mode == .names ? L("\(practice.notes.isEmpty ? practice.selectedStringLabel : "第 \(practice.currentString) 弦") · 全弦找音") : L("第 \(practice.lowerFret)–\(practice.upperFret) 品 · 六根弦")))
                Spacer()
                Text(L("\(practice.answered) / 20 音")).monospacedDigit()
            }.font(.editorial(size: 12 * scale)).foregroundStyle(muted)
            GeometryReader { space in
                let showsBoard = practice.mode != .names || practice.hint
                let gap: CGFloat = 12
                let notationHeight = showsBoard ? max(0, space.size.height - gap) * 0.53 : max(0, space.size.height)
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
                Text(L(practice.notes.isEmpty ? L("开启输入后，点击开始练习。") : practice.feedback))
            }.font(.editorial(size: 13 * scale))
                .foregroundStyle(practice.feedbackKind == 0 ? muted : ink)
                .frame(minHeight: 22 * scale)
        }
    }
    private var notation: some View {
        Group {
            if practice.notes.isEmpty {
                VStack(spacing: 12) {
                    Text(L("准备练习")).font(.editorial(size: 24 * scale))
                    Text(L("每组 20 个音")).font(.editorial(size: 13 * scale)).foregroundStyle(muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if practice.mode == .names {
                VStack(spacing: 8) {
                    Text(L(practice.completed ? L("完成") : L("弹出这个音"))).font(.editorial(size: 13 * scale)).foregroundStyle(muted)
                    Text(L((practice.target ?? practice.notes.last)?.name ?? "—"))
                        .font(.editorial(size: 72 * scale)).tracking(-1.44 * scale).minimumScaleFactor(0.5)
                    Text(L("第 \(practice.currentString) 弦")).font(.editorial(size: 14 * scale)).foregroundStyle(muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                StaffView(notes: practice.notes, current: practice.index, showNames: practice.showNames)
            }
        }
    }
    private var summary: some View {
        VStack(spacing: 24) {
            Text(L("练习结束")).font(.editorial(size: 24 * scale, weight: .medium))
            Text(L("已完成 \(practice.answered) 个音，学习记录已更新。")) .foregroundStyle(muted)
            HStack(spacing: 36) {
                metric(practice.accuracy, caption: L("首次正确率"))
                metric(practice.averageTime, caption: L("平均找音时间"))
            }
            Text(L("用过提示或跳过的音会优先安排复习。")) .font(.editorial(size: 12 * scale)).foregroundStyle(muted)
            Button(L("完成")) { practice.showSummary = false }.buttonStyle(EditorialButtonStyle(prominent: true)).keyboardShortcut(.defaultAction)
        }.padding(42).frame(width: 480 * scale).foregroundStyle(ink).background(palette.background)
    }
    private func eyebrow(_ text: String) -> some View { Text(L(text)).font(.editorial(size: 12 * scale, weight: .medium)).foregroundStyle(muted) }
    private func metric(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(value)).font(.editorial(size: 24 * scale, weight: .regular)).monospacedDigit()
            Text(L(caption)).font(.editorial(size: 12 * scale)).foregroundStyle(muted)
        }
    }
}


/// AppKit pop-up menus provide standard selection, keyboard navigation and dismissal.
struct ScaledPicker<Value: Hashable>: View, Localizable {
    @Environment(\.appLanguage) var language
    var title: String? = nil
    var accessibilityName: String? = nil
    var controlWidth: CGFloat? = nil
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    @Environment(\.interfaceScale) private var scale
    var body: some View {
        HStack(spacing: 8) {
            if let title { Text(L(title)).fixedSize() }
            NativeChoicePicker(selection: $selection, options: options, label: label, accessibilityTitle: accessibilityName ?? title ?? label(selection), controlWidth: controlWidth)
                .fixedSize()
                .accessibilityLabel(L(title ?? label(selection)))
        }
        .font(.editorial(size: 12 * scale))
    }
}

struct OpenSettingsButton: View, Localizable {
    @Environment(\.appLanguage) var language
    var body: some View {
        Group {
            if #available(macOS 14.0, *) {
                SettingsLink { Image(systemName: "gearshape") }
            } else {
                Button { NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil) } label: {
                    Image(systemName: "gearshape")
                }
            }
        }.accessibilityLabel(L("设置")).help(L("设置（⌘,）"))
    }
}
