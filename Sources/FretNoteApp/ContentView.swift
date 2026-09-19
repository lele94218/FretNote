import SwiftUI
import FretNoteCore

struct ContentView: View {
    @EnvironmentObject private var appearance: AppearancePreferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme) }
    private var ink: Color { palette.ink }
    private var muted: Color { palette.muted }
    private var rule: Color { palette.rule }
    @ObservedObject var audio: AudioInput
    @ObservedObject var practice: PracticeStore
    var body: some View {
        HStack(spacing: 0) {
            ScrollView { sidebar }.frame(width: 230 * scale)
            Rectangle().fill(rule).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    exercise
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 36) {
                            inputPanel.frame(minWidth: 350 * scale)
                            progressPanel.frame(width: 260 * scale)
                        }
                        VStack(alignment: .leading, spacing: 28) {
                            inputPanel
                            rule.frame(height: 1)
                            progressPanel
                        }
                    }
                    Text("标准调弦 · A4 = 440 Hz · 音频仅在本机处理")
                        .font(.system(size: 12 * scale)).foregroundStyle(muted)
                    if let error = practice.persistenceError { Text(error).font(.system(size: 12 * scale)).foregroundStyle(ink).textSelection(.enabled) }
                }.padding(36)
            }
        }
        .background(palette.background)
        .foregroundStyle(ink)
        .font(.system(size: 13 * scale))
        .tint(ink)
        .saturation(0)
        .sheet(isPresented: $practice.showSummary) {
            summary.preferredColorScheme(appearance.theme.colorScheme)
        }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("FretNote")
                .font(.system(size: 18 * scale, weight: .semibold))
                .padding(.top, 10)
            appearanceControls
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
                            .contentShape(Rectangle())
                    }.buttonStyle(.plain).disabled(practice.active)
                }
            }
            VStack(alignment: .leading, spacing: 17) {
                eyebrow("练习范围")
                if practice.mode != .melody {
                    ScaledPicker(title: "琴弦", selection: $practice.string, options: Array(1...6)) { "第 \($0) 弦" }
                }
                HStack {
                    Text("品位").foregroundStyle(muted).fixedSize()
                    Spacer()
                    ScaledPicker(selection: $practice.lowerFret, options: Array(0...12)) { "\($0)" }
                        .accessibilityLabel("起始品").frame(width: 56 * scale)
                    Text("–").foregroundStyle(muted)
                    ScaledPicker(selection: $practice.upperFret, options: Array(practice.lowerFret...min(17, practice.lowerFret + 5))) { "\($0)" }
                        .accessibilityLabel("结束品").frame(width: 56 * scale)
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
    private var appearanceControls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScaledPicker(title: "外观", selection: $appearance.theme, options: AppTheme.allCases) { $0.title }
            HStack {
                Text("字号")
                Spacer()
                Text("\(Int((appearance.fontScale * 100).rounded()))%")
                    .monospacedDigit().foregroundStyle(muted)
            }
            Slider(value: Binding(get: { appearance.fontScale }, set: { appearance.setFontScale($0) }),
                   in: 1...1.75, step: 0.05)
                .accessibilityLabel("界面字号")
                .accessibilityValue("\(Int((appearance.fontScale * 100).rounded()))%")
            rule.frame(height: 1)
        }.font(.system(size: 12 * scale)).controlSize(.large)
    }
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(practice.mode.rawValue).font(.system(size: 22 * scale, weight: .medium))
            Spacer()
            Text(audio.running ? "正在监听" : "输入未开启")
                .font(.system(size: 12 * scale)).foregroundStyle(muted)
        }
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
                    .frame(height: (practice.mode == .melody ? 176 : 218) * scale)
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
                    .frame(maxWidth: 680 * scale)
            }
            Rectangle().fill(rule).frame(height: 1)
            HStack {
                if practice.active {
                    Button("提示位置") { practice.reveal() }.disabled(practice.completed)
                    Button("跳过") { practice.skip() }.disabled(practice.completed)
                    Spacer()
                    Button("结束练习") { practice.end() }.buttonStyle(MonoButtonStyle())
                } else {
                    Text("\(practice.mode == .names ? "音名 → 指板" : "五线谱 → 指板") · 单音练习")
                        .font(.system(size: 12 * scale)).foregroundStyle(muted)
                    Spacer()
                    Button { practice.start() } label: {
                        Text("开始练习")
                    }.buttonStyle(MonoButtonStyle(prominent: true)).disabled(!audio.running)
                }
            }.buttonStyle(MonoButtonStyle())
        }.padding(.top, 8).padding(.bottom, 24)
            .overlay(alignment: .bottom) { rule.frame(height: 1) }
    }
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { eyebrow("音频输入"); Spacer(); Button { audio.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(audio.running || audio.starting).help("刷新音频设备") }
            ScaledPicker(selection: $audio.selectedDevice, options: audio.devices.map(\.id)) { id in
                audio.devices.first { $0.id == id }?.name ?? "无输入设备"
            }.accessibilityLabel("音频设备").disabled(audio.running || audio.starting)
                .onChange(of: audio.selectedDevice) { _ in audio.channel = 0 }
            HStack {
                ScaledPicker(title: "通道", selection: $audio.channel, options: Array(0..<max(1, audio.channelCount))) { "Input \($0 + 1)" }
                    .disabled(audio.running || audio.starting)
                Spacer()
                Button(audio.starting ? "正在启动…" : (audio.running ? "停止监听" : "开始监听")) {
                    if audio.running { audio.stop() } else { Task { await audio.start() } }
                }.disabled(audio.starting || audio.devices.isEmpty)
            }
            HStack(spacing: 14) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(rule)
                        Rectangle().fill(ink)
                            .frame(width: geometry.size.width * max(0, min(1, (20 * log10(max(0.000001, audio.level)) + 60) / 60)))
                    }
                }.frame(height: 3)
                Text(audio.level > 0 ? String(format: "%.0f dB", 20 * log10(audio.level)) : "— dB")
                    .font(.system(size: 12 * scale, design: .monospaced)).foregroundStyle(muted).frame(width: 60 * scale)
            }
            if audio.level > 0.8 {
                Text("输入电平过高，请降低声卡增益。").font(.system(size: 12 * scale, weight: .medium))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(detectedName).font(.system(size: 24 * scale, weight: .regular)).foregroundStyle(ink)
                Spacer()
                if let reading = audio.reading {
                    Text(String(format: "%.1f Hz  %+.0f ¢", reading.frequency, reading.cents)).font(.system(size: 12 * scale, design: .monospaced)).foregroundStyle(muted)
                } else { Text(audio.running ? "等待清晰的单音" : "连接声卡，选择吉他通道").font(.system(size: 12 * scale)).foregroundStyle(muted) }
            }
            HStack {
                Text("噪声门").font(.system(size: 12 * scale)).foregroundStyle(muted)
                Slider(value: $audio.gateDB, in: -65 ... -25, step: 1).disabled(audio.running || audio.starting)
                Text("\(Int(audio.gateDB)) dB").font(.system(size: 12 * scale, design: .monospaced)).foregroundStyle(muted)
            }
            Text("使用干净音色；重复同音时，轻闷弦再拨。噪声门在停止监听后调整。")
                .font(.system(size: 12 * scale)).foregroundStyle(muted).lineSpacing(3)
            if let error = audio.error {
                Text(error).font(.system(size: 12 * scale)).foregroundStyle(ink).textSelection(.enabled)
                Button("打开麦克风权限设置") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }.font(.system(size: 12 * scale))
            }
        }.buttonStyle(MonoButtonStyle()).controlSize(.large)
    }
    private var detectedName: String {
        guard let reading = audio.reading else { return "—" }
        return "\(GuitarNote.names[(reading.midi % 12 + 12) % 12])\(reading.midi / 12 - 1)"
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
            Button("完成") { practice.showSummary = false }.buttonStyle(MonoButtonStyle(prominent: true))
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


private struct MonoButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    private var palette: AppPalette { AppPalette(scheme: colorScheme) }
    private var ink: Color { palette.ink }
    private var rule: Color { palette.rule }
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12 * scale, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(prominent ? palette.background : ink)
            .background(prominent ? ink : palette.background)
            .overlay(Rectangle().strokeBorder(prominent ? ink : rule, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
            .contentShape(Rectangle())
    }
}


/// A scalable choice control; native macOS popup labels ignore custom font sizes.
private struct ScaledPicker<Value: Hashable>: View {
    var title: String? = nil
    @Binding var selection: Value
    let options: [Value]
    let label: (Value) -> String
    @State private var expanded = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.interfaceScale) private var scale
    @Environment(\.isEnabled) private var enabled
    private var palette: AppPalette { AppPalette(scheme: colorScheme) }
    var body: some View {
        HStack(spacing: 8) {
            if let title { Text(title).fixedSize() }
            Button { expanded.toggle() } label: {
                HStack(spacing: 8) {
                    Text(label(selection)).lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.system(size: 9 * scale))
                }
                .padding(.horizontal, 8).padding(.vertical, 6)
                .foregroundStyle(palette.ink)
                .background(palette.selection)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(label(selection))
            .popover(isPresented: $expanded, arrowEdge: .bottom) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 2) {
                        ForEach(options, id: \.self) { option in
                            Button {
                                selection = option
                                expanded = false
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "checkmark").opacity(option == selection ? 1 : 0)
                                    Text(label(option)).fixedSize()
                                    Spacer(minLength: 0)
                                }
                                .padding(10)
                                .contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }.padding(6)
                }
                .font(.system(size: 12 * scale))
                .foregroundStyle(palette.ink).background(palette.background)
                .frame(width: max(180, CGFloat(options.map { label($0).count }.max() ?? 8) * 12 + 70) * scale,
                       height: min(440, CGFloat(options.count) * (22 * scale + 22) + 12))
                .preferredColorScheme(colorScheme)
            }
        }
        .font(.system(size: 12 * scale))
        .opacity(enabled ? 1 : 0.4)
        .onChange(of: enabled) { if !$0 { expanded = false } }
    }
}
