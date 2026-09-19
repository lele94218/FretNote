import SwiftUI
import FretNoteCore

private let accent = Color(red: 0.39, green: 0.89, blue: 0.74)
private let surface = Color(red: 0.075, green: 0.095, blue: 0.11)
private let muted = Color(red: 0.53, green: 0.6, blue: 0.63)

struct ContentView: View {
    @ObservedObject var audio: AudioInput
    @ObservedObject var practice: PracticeStore
    var body: some View {
        HStack(spacing: 0) {
            sidebar.frame(width: 254)
            Rectangle().fill(.white.opacity(0.07)).frame(width: 1)
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    exercise
                    HStack(alignment: .top, spacing: 18) {
                        inputPanel.frame(maxWidth: .infinity)
                        progressPanel.frame(width: 260)
                    }
                    HStack(spacing: 7) {
                        Image(systemName: "lock.shield")
                        Text("声音仅在本机分析，不录音、不上传。标准调弦 E A D G B E · A4 = 440 Hz")
                    }.font(.system(size: 11)).foregroundStyle(muted)
                    if let error = practice.persistenceError { Text(error).font(.caption).foregroundStyle(.orange).textSelection(.enabled) }
                }.padding(32)
            }
        }
        .background(Color(red: 0.045, green: 0.06, blue: 0.075))
        .tint(accent)
        .sheet(isPresented: $practice.showSummary) { summary }
    }
    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(spacing: 10) {
                Image(systemName: "waveform").font(.system(size: 26, weight: .medium)).foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 3) {
                    Text("FretNote").font(.system(size: 23, weight: .semibold, design: .rounded))
                    Text("听见你的每一步").font(.system(size: 11)).foregroundStyle(muted)
                }
            }.padding(.top, 10)
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("练习")
                ForEach(PracticeMode.allCases) { mode in
                    Button {
                        practice.mode = mode
                        practice.notes = []
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: mode.symbol).frame(width: 22)
                            Text(mode.rawValue).font(.system(size: 14, weight: .medium))
                            Spacer()
                            if practice.mode == mode { Circle().fill(accent).frame(width: 6, height: 6) }
                        }.padding(12).foregroundStyle(practice.mode == mode ? accent : .white.opacity(0.7))
                            .background(practice.mode == mode ? accent.opacity(0.1) : .clear, in: RoundedRectangle(cornerRadius: 10))
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
                    Text("品位").foregroundStyle(muted)
                    Spacer()
                    Picker("起始品", selection: $practice.lowerFret) {
                        ForEach(0...12, id: \.self) { Text("\($0)").tag($0) }
                    }.labelsHidden().frame(width: 66)
                    Text("–").foregroundStyle(muted)
                    Picker("结束品", selection: $practice.upperFret) {
                        ForEach(practice.lowerFret...min(17, practice.lowerFret + 5), id: \.self) { Text("\($0)").tag($0) }
                    }.labelsHidden().frame(width: 66)
                }
                .onChange(of: practice.lowerFret) { value in practice.upperFret = min(max(practice.upperFret, value), value + 5) }
                Toggle("只练自然音", isOn: $practice.naturalsOnly).toggleStyle(.switch).controlSize(.small)
                if practice.mode != .names {
                    Toggle("显示音名辅助", isOn: $practice.showNames).toggleStyle(.switch).controlSize(.small)
                }
                if practice.mode == .melody {
                    Picker("旋律长度", selection: $practice.melodyLength) {
                        ForEach(3...5, id: \.self) { Text("\($0) 个音").tag($0) }
                    }
                }
            }.font(.system(size: 12)).disabled(practice.active)
            Spacer()
            VStack(alignment: .leading, spacing: 9) {
                Image(systemName: "lightbulb").foregroundStyle(accent)
                Text("先找准，再加速。") .font(.system(size: 13, weight: .medium))
                Text("跟着自己的速度练习，暂不考核节奏。弹奏时请遵守指定弦与把位，音频仅验证音高。")
                    .font(.system(size: 11)).foregroundStyle(muted).lineSpacing(5)
            }.padding(15).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12))
            Text("本机练习室  /  v0.1.0").font(.system(size: 10, design: .monospaced)).foregroundStyle(muted)
        }.padding(22).background(surface.opacity(0.7))
    }
    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 8) {
                eyebrow("DAILY PRACTICE  /  每天一点，熟悉整张指板")
                Text(practice.mode.rawValue).font(.system(size: 30, weight: .semibold))
            }
            Spacer()
            HStack(spacing: 7) {
                Circle().fill(audio.running ? accent : muted).frame(width: 7, height: 7)
                Text(audio.running ? "正在监听" : "输入未开启").font(.system(size: 12))
            }.padding(.horizontal, 13).padding(.vertical, 9)
                .background(.white.opacity(0.045), in: Capsule())
        }
    }
    private var exercise: some View {
        VStack(spacing: 20) {
            HStack {
                Label(practice.mode == .melody ? "第 \(practice.lowerFret)–\(practice.upperFret) 品 · 固定把位" : "第 \(practice.string) 弦 · \(practice.lowerFret)–\(practice.upperFret) 品", systemImage: "guitars")
                Spacer()
                Text("\(practice.answered) / 20 音").monospacedDigit()
            }.font(.system(size: 12)).foregroundStyle(muted)
            if practice.notes.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: practice.mode.symbol).font(.system(size: 42, weight: .ultraLight)).foregroundStyle(accent)
                    Text(practice.mode == .names ? "让音名，在指尖找到位置。" : "从谱面，到指尖。")
                        .font(.system(size: 25, weight: .medium))
                    Text("先开启音频输入，再开始一组 20 音的练习。")
                        .font(.system(size: 13)).foregroundStyle(muted)
                }.frame(height: 218)
            } else if practice.mode == .names {
                VStack(spacing: 8) {
                    Text(practice.completed ? "完成" : "弹出这个音").font(.system(size: 13)).foregroundStyle(muted)
                    Text((practice.target ?? practice.notes.last)?.name ?? "—")
                        .font(.system(size: 86, weight: .light, design: .rounded)).foregroundStyle(practice.completed ? accent : .white)
                    Text("第 \(practice.string) 弦").font(.system(size: 14)).foregroundStyle(muted)
                }.frame(height: 218)
            } else {
                StaffView(notes: practice.notes, current: practice.index, showNames: practice.showNames).frame(height: 218)
            }
            HStack(spacing: 8) {
                Image(systemName: practice.feedbackKind > 0 ? "checkmark.circle.fill" : (practice.feedbackKind < 0 ? "arrow.counterclockwise.circle" : "waveform"))
                Text(practice.feedback).font(.system(size: 13))
            }.foregroundStyle(practice.feedbackKind > 0 ? accent : (practice.feedbackKind < 0 ? .orange : muted))
                .frame(height: 22)
            if practice.hint, let note = practice.target {
                FretboardHint(note: note, lower: practice.lowerFret, upper: practice.upperFret)
                    .frame(maxWidth: 420)
            }
            Rectangle().fill(.white.opacity(0.06)).frame(height: 1)
            HStack {
                if practice.active {
                    Button("提示位置") { practice.reveal() }.disabled(practice.completed)
                    Button("跳过") { practice.skip() }.disabled(practice.completed)
                    Spacer()
                    Button("结束练习") { practice.end() }.buttonStyle(.bordered)
                } else {
                    Text("\(practice.mode == .names ? "音名 → 指板" : "五线谱 → 指板") · 单音练习")
                        .font(.system(size: 12)).foregroundStyle(muted)
                    Spacer()
                    Button { practice.start() } label: {
                        Label("开始练习", systemImage: "play.fill").padding(.horizontal, 10).padding(.vertical, 5)
                    }.buttonStyle(.borderedProminent).foregroundStyle(.black).disabled(!audio.running)
                }
            }.buttonStyle(.borderless).controlSize(.large)
        }.padding(24).background(surface, in: RoundedRectangle(cornerRadius: 20))
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(.white.opacity(0.06)))
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
                        Capsule().fill(.white.opacity(0.07))
                        Capsule().fill(audio.level > 0.8 ? Color.orange : accent)
                            .frame(width: geometry.size.width * max(0, min(1, (20 * log10(max(0.000001, audio.level)) + 60) / 60)))
                    }
                }.frame(height: 5)
                Text(audio.level > 0 ? String(format: "%.0f dB", 20 * log10(audio.level)) : "— dB")
                    .font(.system(size: 10, design: .monospaced)).foregroundStyle(muted).frame(width: 44)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(detectedName).font(.system(size: 24, weight: .medium, design: .rounded)).foregroundStyle(accent)
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
                Text(error).font(.system(size: 11)).foregroundStyle(.orange).textSelection(.enabled)
                Button("打开麦克风权限设置") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }.font(.caption)
            }
        }.padding(20).background(surface, in: RoundedRectangle(cornerRadius: 16))
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
            Divider().overlay(.white.opacity(0.05))
            Text("优先复习").font(.system(size: 12, weight: .medium))
            if practice.weakNotes.isEmpty {
                Text("完成第一组练习后，这里会记住需要多练的音。")
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
        }.padding(20).frame(maxWidth: .infinity, alignment: .leading).background(surface, in: RoundedRectangle(cornerRadius: 16))
    }
    private var summary: some View {
        VStack(spacing: 24) {
            Image(systemName: "checkmark.seal").font(.system(size: 44, weight: .light)).foregroundStyle(accent)
            Text("今天，又熟悉了一点。") .font(.system(size: 25, weight: .medium))
            Text("已完成 \(practice.answered) 个音，学习记录已更新。") .foregroundStyle(muted)
            HStack(spacing: 36) {
                metric(practice.accuracy, caption: "首次正确率")
                metric(practice.averageTime, caption: "平均找音时间")
            }
            Text("用过提示或跳过的音会优先安排复习。") .font(.caption).foregroundStyle(muted)
            Button("完成") { practice.showSummary = false }.buttonStyle(.borderedProminent).foregroundStyle(.black)
        }.padding(42).frame(width: 480).background(surface)
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 10, weight: .semibold)).tracking(1.2).foregroundStyle(muted) }
    private func metric(_ value: String, caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 24, weight: .medium, design: .rounded)).monospacedDigit()
            Text(caption).font(.system(size: 10)).foregroundStyle(muted)
        }
    }
}
