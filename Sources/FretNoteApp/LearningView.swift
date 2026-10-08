import SwiftUI
import FretNoteCore

@MainActor
final class LearningStore: ObservableObject {
    @Published var arpeggio = false { didSet { position = 0 } }
    @Published var shell = false { didSet { quality = shell ? .major7 : .major; inversion = 0; position = 0 } }
    @Published var quality: LearningQuality = .major { didSet { position = 0 } }
    @Published var root = 9 { didSet { position = 0 } }
    @Published var bassString = 6 { didSet { position = 0 } }
    @Published var rootString = 6 { didSet { position = 0 } }
    @Published var inversion = 0 { didSet { position = 0 } }
    @Published var path = 1 { didSet { position = 0 } }
    @Published var includeOpen = false { didSet { position = 0 } }
    @Published var position = 0
    var shapes: [LearningShape] {
        LearningShapes.make(root: root, quality: quality, arpeggio: arpeggio,
                            bassString: arpeggio ? rootString : bassString,
                            inversion: arpeggio || shell ? 0 : inversion, path: path, includeOpen: includeOpen)
    }
    var selected: LearningShape? {
        let options = shapes
        return options.isEmpty ? nil : options[min(max(0, position), options.count - 1)]
    }
    func move(_ offset: Int) { position = min(max(0, position + offset), max(0, shapes.count - 1)) }
}

struct LearningView: View {
    @ObservedObject var store: LearningStore
    @ObservedObject var practice: PracticeStore
    @ObservedObject var audio: AudioInput
    @EnvironmentObject private var appearance: AppearancePreferences
    @Environment(\.interfaceScale) private var scale
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    private var palette: AppPalette { AppPalette(scheme: scheme, contrast: contrast) }
    var body: some View {
        HSplitView {
            if appearance.sidebarVisible {
                controls.frame(minWidth: 250, idealWidth: 290, maxWidth: 330)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Button { appearance.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                        .accessibilityLabel("显示或隐藏侧栏")
                    Text(store.arpeggio ? "琶音练习" : "和弦练习").font(.system(size: 20 * scale, weight: .medium))
                    Spacer()
                    OpenSettingsButton()
                }.buttonStyle(.bordered)
                Divider()
                if let shape = store.selected {
                    Text(LearningShapes.roots[store.root] + store.quality.suffix)
                        .font(.system(size: 28 * scale, weight: .medium))
                    Text(shape.tones.map(\.degree).joined(separator: store.arpeggio ? " → " : " – ") + " · 根音在第 \(shape.root.string) 弦")
                        .font(.system(size: 16 * scale))
                    Text(store.arpeggio ? "依次弹奏 · 同一根弦可以有多个音" : "三个音一起弹响 · 排列从低音到高音")
                        .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
                    FretboardView(lower: shape.lower, upper: max(shape.lower + 1, shape.upper), learningTones: shape.tones)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    HStack(alignment: .top, spacing: 16) {
                        ForEach(Array(shape.tones.enumerated()), id: \.offset) { index, tone in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(store.arpeggio ? "第 \(index + 1) 音 · \(tone.degree)" : "音级 \(tone.degree)")
                                    .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
                                Text(tone.name).font(.system(size: 24 * scale, weight: .medium))
                                Text("\(tone.note.string) 弦 · \(tone.note.fret) 品")
                                    .font(.system(size: 12 * scale))
                            }.frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("这个组合没有可显示的位置")
                        Text(store.arpeggio && store.rootString == 2 && store.path == 2
                             ? "三弦路径需要根音上方还有两根弦，请更换路径或根音弦。"
                             : "请更换根音、弦组或路径。")
                            .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
                    }.frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Divider()
                HStack {
                    Button("上一位置") { store.move(-1) }.disabled(store.position == 0)
                    Text(store.shapes.isEmpty ? "无可用位置" : "位置 \(store.position + 1) / \(store.shapes.count)")
                        .monospacedDigit().foregroundStyle(palette.muted)
                    Button("下一位置") { store.move(1) }.disabled(store.position + 1 >= store.shapes.count)
                    Spacer(minLength: 0)
                }.font(.system(size: 12 * scale)).buttonStyle(.bordered)
            }.padding(20).frame(minWidth: 600)
        }
        .font(.system(size: 13 * scale))
        .foregroundStyle(palette.ink).background(palette.background).tint(palette.ink)
    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExerciseNavigation(practice: practice, audio: audio, learning: store)
            Picker("材料", selection: $store.shell) {
                Text("135").tag(false)
                Text("137").tag(true)
            }.pickerStyle(.segmented)
            row("类别") {
                ScaledPicker(controlWidth: 105, selection: $store.quality,
                             options: LearningQuality.allCases.filter { $0.isShell == store.shell }) {
                    String($0.title.split(separator: " ").first!)
                }
            }
            row("根音") {
                ScaledPicker(controlWidth: 105, selection: $store.root, options: Array(0..<12)) { LearningShapes.roots[$0] }
            }
            if store.arpeggio {
                row("根音弦") {
                    ScaledPicker(controlWidth: 85, selection: $store.rootString, options: Array((2...6).reversed())) { "第 \($0) 弦" }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("路径").foregroundStyle(palette.muted)
                    ScaledPicker(controlWidth: 140, selection: $store.path, options: Array(0...2)) {
                        ["前两音同弦", "后两音同弦", "每弦一个音"][$0]
                    }
                }
            } else {
                row("弦组") {
                    ScaledPicker(controlWidth: 105, selection: $store.bassString, options: Array((3...6).reversed())) { "\($0)\($0 - 1)\($0 - 2)" }
                }
                if !store.shell {
                    row("排列") {
                        ScaledPicker(controlWidth: 105, selection: $store.inversion, options: Array(0...2)) { index in
                            let degrees = store.quality.degrees
                            return (Array(degrees[index...]) + Array(degrees[..<index])).joined(separator: "–")
                        }
                    }
                }
            }
            Toggle("包含空弦", isOn: $store.includeOpen).toggleStyle(.checkbox)
            Spacer(minLength: 8)
            Text("学习模式 · 无需输入")
                .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
        }.padding(20)
    }
    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack { Text(title).foregroundStyle(palette.muted); Spacer(minLength: 6); control() }
    }
}

/// The same peer navigation is present in every exercise screen.
struct ExerciseNavigation: View {
    @ObservedObject var practice: PracticeStore
    @ObservedObject var audio: AudioInput
    @ObservedObject var learning: LearningStore
    @Environment(\.interfaceScale) private var scale
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    private var palette: AppPalette { AppPalette(scheme: scheme, contrast: contrast) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("练习").font(.system(size: 12 * scale, weight: .medium)).foregroundStyle(palette.muted)
            ForEach(PracticeMode.allCases) { mode in
                item(mode.rawValue, selected: !practice.learning && practice.mode == mode) {
                    practice.setLearning(false, audio: audio)
                    practice.mode = mode
                    practice.notes = []
                }
            }
            item("和弦练习", selected: practice.learning && !learning.arpeggio) {
                learning.arpeggio = false
                practice.setLearning(true, audio: audio)
            }
            item("琶音练习", selected: practice.learning && learning.arpeggio) {
                learning.arpeggio = true
                practice.setLearning(true, audio: audio)
            }
        }.disabled(practice.active)
    }
    private func item(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title).font(.system(size: 14 * scale, weight: .medium))
                Spacer()
                if selected { Text("—") }
            }.padding(.vertical, 5).padding(.horizontal, 8)
                .foregroundStyle(selected ? palette.ink : palette.muted)
                .background(selected ? palette.selection : Color.clear, in: RoundedRectangle(cornerRadius: 6))
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
