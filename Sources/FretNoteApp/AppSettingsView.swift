import AVFoundation
import SwiftUI
import FretNoteCore

struct AppSettingsView: View {
    @EnvironmentObject private var appearance: AppearancePreferences
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.interfaceScale) private var scale
    @ObservedObject var audio: AudioInput
    private var palette: AppPalette { AppPalette(scheme: colorScheme, contrast: contrast) }
    private var ink: Color { palette.ink }
    private var muted: Color { palette.muted }
    private var rule: Color { palette.rule }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("设置").font(.system(size: 22 * scale, weight: .medium))
                appearanceControls
                inputPanel
            }.padding(28)
        }
        .frame(width: 560, height: 640)
        .font(.system(size: 13 * scale))
        .foregroundStyle(ink).background(palette.background).tint(ink)
    }
    private func eyebrow(_ text: String) -> some View { Text(text).font(.system(size: 12 * scale, weight: .medium)).foregroundStyle(muted) }
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
    private var inputPanel: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack { eyebrow("音频输入"); Spacer(); Button { audio.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(audio.running || audio.starting).help("刷新音频设备").accessibilityLabel("刷新音频设备") }
            ScaledPicker(accessibilityName: "音频设备", selection: $audio.selectedDevice, options: audio.devices.map(\.id)) { id in
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
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("输入电平")
            .accessibilityValue(audio.level > 0 ? String(format: "%.0f 分贝", 20 * log10(audio.level)) : "无信号")
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
                Slider(value: $audio.gateDB, in: -65 ... -25, step: 1).accessibilityLabel("噪声门").accessibilityValue("\(Int(audio.gateDB)) 分贝").disabled(audio.running || audio.starting)
                Text("\(Int(audio.gateDB)) dB").font(.system(size: 12 * scale, design: .monospaced)).foregroundStyle(muted)
            }
            Text("使用干净音色；重复同音时，轻闷弦再拨。噪声门在停止监听后调整。")
                .font(.system(size: 12 * scale)).foregroundStyle(muted).lineSpacing(3)
            if let error = audio.error {
                Text(error).font(.system(size: 12 * scale)).foregroundStyle(ink).textSelection(.enabled)
                if AVCaptureDevice.authorizationStatus(for: .audio) == .denied { Button("打开麦克风权限设置") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone")!) }.font(.system(size: 12 * scale)) }
            }
        }.buttonStyle(.bordered).controlSize(.large)
    }
    private var detectedName: String {
        guard let reading = audio.reading else { return "—" }
        return "\(GuitarNote.names[(reading.midi % 12 + 12) % 12])\(reading.midi / 12 - 1)"
    }
}
