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
    var body: some View {
        HSplitView {
            if appearance.sidebarVisible {
                ScrollView { sidebar }
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
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if let error = audio.error {
                            Text(error).foregroundStyle(ink).textSelection(.enabled)
                            OpenSettingsButton()
                        }
                        exercise
                        progressPanel
                        Text("标准调弦 · A4 = 440 Hz · 音频仅在本机处理")
                            .font(.system(size: 12 * scale)).foregroundStyle(muted)
                        if let error = practice.persistenceError {
                            Text(error).font(.system(size: 12 * scale)).textSelection(.enabled)
                        }
                    }.padding(24)
                }
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
        .sheet(isPresented: $practice.showSummary) {
            summary.preferredColorScheme(appearance.theme.colorScheme)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("FretNote")
                .font(.system(size: 18 * scale, weight: .semibold))
                .padding(.top, 10)
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
                        }.padding(.vertical, 10).foregroundStyle(practice.mode == mode ? ink : muted)
                            .padding(.horizontal, 8)
                            .background(practice.mode == mode ? palette.selection : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(practice.active)
                    .accessibilityAddTraits(practice.mode == mode ? [.isSelected] : [])
                }
            }
            VStack(alignment: .leading, spacing: 17) {
                eyebrow("练习范围")
                if practice.mode != .melody {
                    ScaledPicker(title: "琴弦", selection: $practice.string, options: Array(1...6)) { "第 \($0) 弦" }
                }
                VStack(spacing: 12) {
                    HStack { Text("起始品"); Spacer(); ScaledPicker(accessibilityName: "起始品", selection: $practice.lowerFret, options: Array(0...12)) { "\($0)" }.accessibilityLabel("起始品") }
                    HStack { Text("结束品"); Spacer(); ScaledPicker(accessibilityName: "结束品", selection: $practice.upperFret, options: Array(practice.lowerFret...min(17, practice.lowerFret + 5))) { "\($0)" }.accessibilityLabel("结束品") }
                }
                .onChange(of: practice.lowerFret) { value in practice.upperFret = min(max(practice.upperFret, value), value + 5) }
                Toggle("只练自然音", isOn: $practice.naturalsOnly).toggleStyle(.checkbox).controlSize(.large)
                if practice.mode != .names {
                    Toggle("显示音名辅助", isOn: $practice.showNames).toggleStyle(.checkbox).controlSize(.large)
                }
                if practice.mode == .melody {
                    ScaledPicker(title: "旋律长度", selection: $practice.melodyLength, options: Array(3...5)) { "\($0) 个音" }
                }
            }.font(.system(size: 12 * scale)).disabled(practice.active)
            Spacer()
            Text("单音练习，不考核节奏。\n请按指定弦与把位弹奏。")
                .font(.system(size: 12 * scale)).foregroundStyle(muted).lineSpacing(5)
        }.padding(24)
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
        VStack(spacing: 20) {
            HStack {
                Text(practice.mode == .melody ? "第 \(practice.lowerFret)–\(practice.upperFret) 品" : "第 \(practice.string) 弦 · \(practice.lowerFret)–\(practice.upperFret) 品")
                Spacer()
                Text("\(practice.answered) / 20 音").monospacedDigit()
            }.font(.system(size: 12 * scale)).foregroundStyle(muted)
            if practice.notes.isEmpty {
                VStack(spacing: 16) {
                    Text("准备练习")
                        .font(.system(size: 24 * scale, weight: .regular))
                    Text("开启音频输入后，点击开始。每组 20 个音。")
                        .font(.system(size: 13 * scale)).foregroundStyle(muted)
                }.frame(height: 218 * scale)
            } else if practice.mode == .names {
                VStack(spacing: 8) {
                    Text(practice.completed ? "完成" : "弹出这个音").font(.system(size: 13 * scale)).foregroundStyle(muted)
                    Text((practice.target ?? practice.notes.last)?.name ?? "—")
                        .font(.system(size: 86 * scale, weight: .regular)).foregroundStyle(ink)
                    Text("第 \(practice.string) 弦").font(.system(size: 14 * scale)).foregroundStyle(muted)
                }.frame(height: 218 * scale)
            } else {
                StaffView(notes: practice.notes, current: practice.index, showNames: practice.showNames)
            }
            HStack(spacing: 8) {
                if practice.feedbackKind != 0 {
                    Image(systemName: practice.feedbackKind > 0 ? "checkmark" : "xmark")
                }
                Text(practice.notes.isEmpty ? "" : practice.feedback).font(.system(size: 13 * scale))
            }.foregroundStyle(practice.feedbackKind == 0 ? muted : ink)
                .frame(minHeight: 22 * scale)
            if practice.mode == .melody || practice.hint {
                FretboardView(lower: practice.lowerFret, upper: practice.upperFret,
                              highlightedNote: practice.hint ? practice.target : nil,
                              emphasizedString: practice.mode == .melody ? nil : practice.string)
            }
        }.padding(.top, 8).padding(.bottom, 24)
            .overlay(alignment: .bottom) { rule.frame(height: 1) }
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
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    @Environment(\.interfaceScale) private var scale
    var body: some View {
        HStack(spacing: 8) {
            if let title { Text(title).fixedSize() }
            NativeChoicePicker(selection: $selection, options: options, label: label, accessibilityTitle: accessibilityName ?? title ?? label(selection))
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
