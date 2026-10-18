import SwiftUI
import FretNoteCore

@MainActor
final class LearningStore: ObservableObject {
    @Published var arpeggio = false { didSet { position = 0 } }
    @Published var quality: LearningQuality = .major { didSet { position = 0 } }
    @Published var root = 9 { didSet { position = 0 } }
    @Published var position = 0
    var catalog: [LearningExample] { LearningShapes.catalog(root: root, quality: quality, arpeggio: arpeggio) }

}

struct LearningView: View, Localizable {
    @Environment(\.appLanguage) var language
    @ObservedObject var store: LearningStore
    @ObservedObject var practice: PracticeStore
    @ObservedObject var audio: AudioInput
    @ObservedObject var drill: ShapePracticeStore
    @State private var showHistory = false
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
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Button { appearance.sidebarVisible.toggle() } label: { Image(systemName: "sidebar.left") }
                        .accessibilityLabel(L("显示或隐藏侧栏"))
                    Text(L(store.arpeggio ? L("琶音练习") : L("和弦练习"))).font(.editorial(size: 20 * scale, weight: .regular))
                    Spacer()
                    OpenSettingsButton()
                }.buttonStyle(EditorialButtonStyle())
                Divider()
                HStack(spacing: 24) {
                    modeLink(L("学习"), practicing: false)
                    modeLink(L("练习"), practicing: true)
                }
                HStack {
                    Text(L(LearningShapes.roots[store.root] + store.quality.suffix))
                        .font(.editorial(size: 24 * scale, weight: .regular)).tracking(-0.48 * scale)
                    Spacer()
                    if !drill.practicing {
                        Button(L("开始练习")) { drill.practicing = true; startPractice() }
                            .buttonStyle(EditorialButtonStyle(prominent: true)).disabled(audio.starting)
                    }
                }
                if drill.practicing { exercise }
                else {
                Text(L(store.arpeggio ? L("依次弹奏 · 各种路径按品位排列") : L("三个音一起响 · 各弦组与排列按品位展示")))
                    .font(.editorial(size: 12 * scale)).foregroundStyle(palette.muted)
                gallery
                }
            }.padding(20).frame(minWidth: 600)
        }
        .font(.editorial(size: 13 * scale))
        .foregroundStyle(palette.ink).background(palette.background).tint(palette.ink)
        .onChange(of: store.root) { _ in drill.clear() }
        .onChange(of: store.quality) { _ in drill.clear() }
        .sheet(isPresented: $showHistory) { LearningHistoryView(practice: practice) }

    }
    private var controls: some View {
        VStack(alignment: .leading, spacing: 12) {
            ExerciseNavigation(practice: practice, audio: audio, learning: store, drill: drill)
            Group {
            row(L("根音")) {
                ScaledPicker(controlWidth: 105, selection: $store.root, options: Array(0..<12)) { LearningShapes.roots[$0] }
            }
            row(L("类别")) {
                ScaledPicker(controlWidth: 105, selection: $store.quality, options: LearningQuality.allCases) {
                    String($0.title.split(separator: " ").first!)
                }
            }
            }.disabled(drill.active || audio.starting)
            Spacer(minLength: 8)
            Button(L("学习记录")) { showHistory = true }.buttonStyle(EditorialButtonStyle())
            Text(L(drill.practicing ? (store.arpeggio ? L("逐音判定 · 注意止音") : L("多音判定 · 使用干净音色")) : L("学习模式 · 无需输入")))
                .font(.editorial(size: 12 * scale)).foregroundStyle(palette.muted)
        }.padding(20)
    }
    private func modeLink(_ title: String, practicing: Bool) -> some View {
        let selected = drill.practicing == practicing
        return Button {
            if practicing { drill.practicing = true }
            else { drill.reset(records: practice, audio: audio) }
        } label: {
            Text(L(title)).font(.editorial(size: 13 * scale))
                .foregroundStyle(selected ? palette.ink : palette.muted)
                .underline(selected, color: palette.ink)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
    private func startPractice() {
        guard !audio.starting, !drill.active else { return }
        audio.learningMode = false
        audio.chordMode = !store.arpeggio
        Task {
            await audio.start()
            guard audio.running, drill.practicing else { return }
            drill.start(catalog: store.catalog, arpeggio: store.arpeggio,
                        name: LearningShapes.roots[store.root] + store.quality.suffix, shell: store.quality.isShell)
        }
    }
    private var exercise: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !store.arpeggio {
                Text(L("多音判定（试用）· 先止音，再拨响三个音并保持延音"))
                    .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            }
            if let question = drill.question {
                Text(L(question.shape.tones.map(\.degree).joined(separator: store.arpeggio ? " → " : " – ") + L(" · 根音 \(question.shape.root.string) 弦")))
                    .font(.editorial(size: 16 * scale))
                Text(L(question.label + L(" · 音区 ") + question.shape.tones.map { $0.name + String($0.note.midi / 12 - 1) }.joined(separator: " / ")))
                    .font(.editorial(size: 12 * scale)).foregroundStyle(palette.muted)
                FretboardView(lower: question.shape.lower, upper: max(question.shape.lower + 1, question.shape.upper),
                              learningTones: drill.revealed || drill.completed ? question.shape.tones : [])
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if store.arpeggio {
                    Text(L("三音进度 \(drill.noteIndex) / 3"))
                        .font(.editorial(size: 13 * scale)).monospacedDigit()
                }
                Text(L(drill.feedback)).font(.editorial(size: 13 * scale))
                Text(L("第 \(drill.questionIndex + 1) / \(drill.questions.count) 题 · 首次正确 \(drill.session?.accuracy ?? "—")"))
                    .font(.editorial(size: 12 * scale)).foregroundStyle(palette.muted)
            } else {
                Text(L(store.arpeggio ? L("依次弹出三个目标音。App 检查音高、八度和顺序。") : L("三个目标音一起响。App 检查实际音高组合，不将三个分离的单音累加。")))
                    .font(.editorial(size: 14 * scale))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            if let error = audio.error ?? practice.persistenceError {
                Text(L(error)).font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            }
            if audio.running && !store.arpeggio && drill.active && !drill.completed {
                Text(L(audio.chordReading.map { L("听到 ") + $0.midis.map { GuitarNote.names[$0 % 12] + String($0 / 12 - 1) }.joined(separator: " · ") } ?? L("等待清晰的三个音…")))
                    .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            }
            Divider()
            ViewThatFits(in: .horizontal) {
                HStack { exerciseButtons }
                VStack(alignment: .leading, spacing: 8) { exerciseButtons }
            }.buttonStyle(EditorialButtonStyle()).font(.editorial(size: 12 * scale))
        }
    }
    @ViewBuilder private var exerciseButtons: some View {
        if drill.active {
            if drill.completed {
                if drill.hasNext { Button(L("下一题")) { drill.next() } }
            } else {
                Button(L("提示指型")) { drill.reveal() }
                Button(L("跳过")) { drill.skip(records: practice) }
            }
            Button(L("结束练习")) { drill.end(records: practice); audio.stop() }
        } else {
            Button(audio.starting ? L("正在开启输入…") : L("开始练习")) { startPractice() }
                .buttonStyle(EditorialButtonStyle(prominent: true)).disabled(audio.starting || audio.devices.isEmpty)
        }
    }
    private var gallery: some View {
        GeometryReader { space in
            let columns = space.size.width >= 780 && scale <= 1.25 ? 2 : 1
            let diagramHeight: CGFloat = scale > 1.25 ? 128 : 144
            let rows = max(1, Int((space.size.height - 46) / (diagramHeight + 36 + 24 * scale)))
            let count = columns * rows
            let examples = store.catalog
            let pages = max(1, (examples.count + count - 1) / count)
            let page = min(store.position, pages - 1)
            let visible = Array(examples.dropFirst(page * count).prefix(count))
            VStack(spacing: 12) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 20), count: columns), spacing: 12) {
                    ForEach(visible) { example in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(L(example.label))
                                Spacer()
                                Text(L(example.shape.tones.map(\.degree).joined(separator: store.arpeggio ? "→" : "–")))
                            }.font(.editorial(size: 12 * scale, weight: .medium))
                            Text(L(L("根音 \(example.shape.root.string) 弦 · ") + example.shape.tones.map(\.name).joined(separator: " · ")))
                                .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
                            FretboardView(lower: example.shape.lower, upper: max(example.shape.lower + 1, example.shape.upper), learningTones: example.shape.tones, showsCaption: false)
                                .frame(height: diagramHeight)
                                .environment(\.interfaceScale, min(scale, 1.25))
                            Color.clear.frame(height: 1)
                        }
                    }
                }
                Spacer(minLength: 0)
                HStack {
                    Button(L("上一页")) { store.position = max(0, page - 1) }.disabled(page == 0)
                    Text(L("\(page + 1) / \(pages) · \(examples.count) 个指型"))
                        .foregroundStyle(palette.muted).monospacedDigit()
                    Button(L("下一页")) { store.position = min(pages - 1, page + 1) }.disabled(page + 1 >= pages)
                    Spacer(minLength: 0)
                }.font(.editorial(size: 12 * scale)).buttonStyle(EditorialButtonStyle())
            }
        }
    }
    private func row<Control: View>(_ title: String, @ViewBuilder control: () -> Control) -> some View {
        HStack { Text(L(title)).foregroundStyle(palette.muted); Spacer(minLength: 6); control() }
    }
}

/// The same peer navigation is present in every exercise screen.
struct ExerciseNavigation: View, Localizable {
    @Environment(\.appLanguage) var language
    @ObservedObject var practice: PracticeStore
    @ObservedObject var audio: AudioInput
    @ObservedObject var learning: LearningStore
    @ObservedObject var drill: ShapePracticeStore
    @Environment(\.interfaceScale) private var scale
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    private var palette: AppPalette { AppPalette(scheme: scheme, contrast: contrast) }
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(L("FRETNOTE")).font(.editorial(size: 12 * scale, weight: .regular)).tracking(0.25 * scale).foregroundStyle(palette.ink)
            ForEach(PracticeMode.allCases) { mode in
                item(mode.rawValue, selected: !practice.learning && practice.mode == mode) {
                    drill.reset(records: practice, audio: audio)
                    practice.setLearning(false, audio: audio)
                    practice.mode = mode
                    practice.notes = []
                }
            }
            item(L("和弦练习"), selected: practice.learning && !learning.arpeggio) {
                drill.reset(records: practice, audio: audio)
                learning.arpeggio = false
                practice.setLearning(true, audio: audio)
            }
            item(L("琶音练习"), selected: practice.learning && learning.arpeggio) {
                drill.reset(records: practice, audio: audio)
                learning.arpeggio = true
                practice.setLearning(true, audio: audio)
            }
        }.disabled(practice.active || drill.active || audio.starting)
    }
    private func item(_ title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(L(title)).font(.editorial(size: 14 * scale, weight: .regular)).underline(selected, color: palette.ink)
                Spacer()
            }.padding(.vertical, 5)
                .foregroundStyle(selected ? palette.ink : palette.muted)
                .contentShape(Rectangle())
        }.buttonStyle(.plain).accessibilityAddTraits(selected ? [.isSelected] : [])
    }
}
