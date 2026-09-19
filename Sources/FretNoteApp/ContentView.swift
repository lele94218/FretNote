import SwiftUI
import FretNoteCore

private let ink = Color(white: 0.08)
private let muted = Color(white: 0.42)
private let rule = Color(white: 0.88)

struct ContentView: View {
    @ObservedObject var audio: AudioInput
    @ObservedObject var practice: PracticeStore
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 230)
            Rectangle().fill(rule).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    header
                    exercise
                    HStack(alignment: .top, spacing: 36) {
                        inputPanel.frame(maxWidth: .infinity)
                        progressPanel.frame(width: 260)
                    }
                    Text("标准调弦 · A4 = 440 Hz · 音频仅在本机处理")
                        .font(.system(size: 11)).foregroundStyle(muted)
                    if let error = practice.persistenceError { Text(error).font(.caption).foregroundStyle(ink).textSelection(.enabled) }
                }.padding(36)
            }
        }
        .background(Color.white)
        .foregroundStyle(ink)
        .tint(ink)
        .saturation(0)
        .sheet(isPresented: $practice.showSummary) { summary }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            Text("FretNote")
                .font(.system(size: 18, weight: .semibold))
                .padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("练习")
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        practice.mode = mode
                        practice.notes = []
                    } label: {
                        HStack(spacing: 12) {
                            Text(mode.rawValue).font(.system(size: 14, weight: .medium))
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
                    Picker("琴弦", selection: $practice.string) {
                        ForEach(1...6, id: \.self) { Text("第 \($0) 弦").tag($0) }
                    }
                }
                HStack {
                    Text("品位").foregroundStyle(muted).fixedSize()
                    Spacer()
                    Picker("起始品", selection: $practice.lowerFret) {
                        ForEach(0...12, id: \.self) { Text("\($0)").tag($0) }
                    }.labelsHidden().frame(width: 56)
                    Text("–").foregroundStyle(muted)
                    Picker("结束品", selection: $practice.upperFret) {
                        ForEach(practice.lowerFret...min(17, practice.lowerFret + 5), id: \.self) { Text("\($0)").tag($0) }
                    }.labelsHidden().frame(width: 56)
                }
                .onChange(of: practice.lowerFret) { value in practice.upperFret = min(max(practice.upperFret, value), value + 5) }
                Toggle("只练自然音", isOn: $practice.naturalsOnly).toggleStyle(.checkbox).controlSize(.small)
                if practice.mode != .names {
                    Toggle("显示音名辅助", isOn: $practice.showNames).toggleStyle(.checkbox).controlSize(.small)
                }
                if practice.mode == .melody {
                    Picker("旋律长度", selection: $practice.melodyLength) {
                        ForEach(3...5, id: \.self) { Text("\($0) 个音").tag($0) }
                    }
                }
            }.font(.system(size: 12)).disabled(practice.active)
            Spacer()
            Text("单音练习，不考核节奏。\n请按指定弦与把位弹奏。")
                .font(.system(size: 11)).foregroundStyle(muted).lineSpacing(5)
        }.padding(24)
    }
    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(practice.mode.rawValue).font(.system(size: 22, weight: .medium))
            Spacer()
            Text(audio.running ? "正在监听" : "输入未开启")
                .font(.system(size: 12)).foregroundStyle(muted)
        }
    }
    private var exercise: some View {
        VStack(spacing: 20) {
            HStack {
                Text(practice.mode == .melody ? "第 \(practice.lowerFret)–\(practice.upperFret) 品" : "第 \(practice.string) 弦 · \(practice.lowerFret)–\(practice.upperFret) 品")
                Spacer()
                Text("\(practice.answered) / 20 音").monospacedDigit()
            }.font(.system(size: 12)).foregroundStyle(muted)
            if practice.notes.isEmpty {
                VStack(spacing: 16) {
                    Text("准备练习")
                        .font(.system(size: 24, weight: .regular))
                    Text("开启音频输入后，点击开始。每组 20 个音。")
                        .font(.system(size: 13)).foregroundStyle(muted)
                }.frame(height: 218)
            } else if practice.mode == .names {
                VStack(spacing: 8) {
                    Text(practice.completed ? "完成" : "弹出这个音").font(.system(size: 13)).foregroundStyle(muted)
                    Text((practice.target ?? practice.notes.last)?.name ?? "—")
                        .font(.system(size: 86, weight: .regular)).foregroundStyle(ink)
                    Text("第 \(practice.string) 弦").font(.system(size: 14)).foregroundStyle(muted)
                }.frame(height: 218)
            } else {
                StaffView(notes: practice.notes, current: practice.index, showNames: practice.showNames).frame(height: 218)
            }
            HStack(spacing: 8) {
                if practice.feedbackKind != 0 {
                    Image(systemName: practice.feedbackKind > 0 ? "checkmark" : "xmark")
                }
                Text(practice.notes.isEmpty ? "" : practice.feedback).font(.system(size: 13))
            }.foregroundStyle(practice.feedbackKind == 0 ? muted : ink)
                .frame(height: 22)
            if practice.hint, let note = practice.target {
                FretboardHint(note: note, lower: practice.lowerFret, upper: practice.upperFret)
                    .frame(maxWidth: 420)
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
                        .font(.system(size: 12)).foregroundStyle(muted)
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
            Picker("设备", selection: $audio.selectedDevice) {
                ForEach(audio.devices) { Text($0.name).tag($0.id) }
            }.labelsHidden().disabled(audio.running || audio.starting)
                .onChange(of: audio.selectedDevice) { _ in audio.channel = 0 }
            HStack {
                Picker("通道", selection: $audio.channel) {
                    ForEach(0..<max(1, audio.channelCount), id: \.self) { Text("Input \($0 + 1)").tag($0) }
                }.disabled(audio.running || audio.starting)
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
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted).frame(width: 44)
            }
            if audio.level > 0.8 {
                Text("输入电平过高，请降低声卡增益。").font(.system(size: 11, weight: .medium))
            }
            HStack(alignment: .firstTextBaseline) {
                Text(detectedName).font(.system(size: 24, weight: .regular)).foregroundStyle(ink)
                Spacer()
                if let reading = audio.reading {
                    Text(String(format: "%.1f Hz  %+.0f ¢", reading.frequency, reading.cents)).font(.system(size: 11, design: .monospaced)).foregroundStyle(muted)
                } else { Text(audio.running ? "等待清晰的单音" : "连接声卡，选择吉他通道").font(.system(size: 11)).foregroundStyle(muted) }
            }
            HStack {
                Text("噪声门").font(.system(size: 11)).foregroundStyle(muted)
                Slider(value: $audio.gateDB, in: -65 ... -25, step: 1).disabled(audio.running || audio.starting)
                Text("\(Int(audio.gateDB)) dB").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
            }
            Text("使用干净音色；重复同音时，轻闷弦再拨。噪声门在停止监听后调整。")
                .font(.system(size: 10)).foregroundStyle(muted).lineSpacing(3)
            if let error = audio.error {
                Text(error).font(.system(size: 11)).foregroundStyle(ink).textSelection(.enabled)
                Button("打开麦克风权限设置") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }.font(.caption)
            }
        }.buttonStyle(MonoButtonStyle()).controlSize(.small)
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
            Text("优先复习").font(.system(size: 12, weight: .medium))
            if practice.weakNotes.isEmpty {
                Text("暂无记录")
                    .font(.system(size: 12)).foregroundStyle(muted).lineSpacing(5)
            } else {
                ForEach(Array(practice.weakNotes.prefix(3)), id: \.note.id) { item in
                    HStack {
                        Text("\(item.note.string) 弦 · \(item.note.name)")
                        Spacer()
                        Text("\(Int(item.score.accuracy * 100))%").foregroundStyle(muted).monospacedDigit()
                    }.font(.system(size: 12))
                }
            }
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
    private var summary: some View {
        VStack(spacing: 24) {
            Text("练习结束").font(.system(size: 24, weight: .medium))
            Text("已完成 \(practice.answered) 个音，学习记录已更新。") .foregroundStyle(muted)
            HStack(spacing: 36) {
                metric(practice.accuracy, caption: "首次正确率")
                metric(practice.averageTime, caption: "平均找音时间")
            }
            Text("用过提示或跳过的音会优先安排复习。") .font(.caption).foregroundStyle(muted)
            Button("完成") { practice.showSummary = false }.buttonStyle(MonoButtonStyle(prominent: true))
        }.padding(42).frame(width: 480).foregroundStyle(ink).background(Color.white)
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 12, weight: .medium)).foregroundStyle(muted) }
    private func metric(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 24, weight: .regular)).monospacedDigit()
            Text(caption).font(.system(size: 10)).foregroundStyle(muted)
        }
    }
}


private struct MonoButtonStyle: ButtonStyle {
    var prominent = false
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12, weight: .medium))
            .padding(.horizontal, 14).padding(.vertical, 8)
            .foregroundStyle(prominent ? Color.white : ink)
            .background(prominent ? ink : Color.white)
            .overlay(Rectangle().strokeBorder(prominent ? ink : rule, lineWidth: 1))
            .opacity(enabled ? (configuration.isPressed ? 0.65 : 1) : 0.35)
            .contentShape(Rectangle())
    }
}
