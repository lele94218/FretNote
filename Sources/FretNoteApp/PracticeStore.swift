import Foundation
import FretNoteCore

@MainActor
final class PracticeStore: ObservableObject {
    @Published var mode: PracticeMode = .names
    @Published var string = 1
    @Published var lowerFret = 1 {
        didSet { customUpperFret = min(max(customUpperFret, lowerFret), min(17, lowerFret + 5)) }
    }
    @Published var customRange = false {
        didSet {
            if !customRange && lowerFret == 0 { lowerFret = 1 }
            customUpperFret = lowerFret + 3
        }
    }
    @Published private var customUpperFret = 4
    var upperFret: Int {
        get { customRange ? customUpperFret : lowerFret + 3 }
        set { customUpperFret = min(max(newValue, lowerFret), min(17, lowerFret + 5)) }
    }
    @Published var naturalsOnly = true
    @Published var showNames = true
    @Published var melodyLength = 4
    @Published var notes: [GuitarNote] = []
    @Published var index = 0
    @Published var active = false
    @Published var completed = false
    @Published var feedback = "等待开始。"
    @Published var feedbackKind = 0
    @Published var hint = false
    @Published var progress: [String: NoteProgress] = [:]
    @Published var answered = 0
    @Published var firstCorrect = 0
    @Published var totalSeconds = 0.0
    @Published var persistenceError: String?
    @Published var showSummary = false
    private var wrong = false
    private var began = Date()
    private var ignoreUntil = Date.distantPast
    private var nextTask: Task<Void, Never>?
    private var canSave = true
    private let file: URL
    var target: GuitarNote? { notes.indices.contains(index) ? notes[index] : nil }
    var accuracy: String { answered == 0 ? "—" : "\(Int(Double(firstCorrect) / Double(answered) * 100))%" }
    var averageTime: String { answered == 0 ? "—" : String(format: "%.1f 秒", totalSeconds / Double(answered)) }
    var weakNotes: [(note: GuitarNote, score: NoteProgress)] {
        progress.compactMap { key, value -> (note: GuitarNote, score: NoteProgress)? in
            let parts = key.split(separator: ":").compactMap { Int($0) }
            guard parts.count == 2, (1...6).contains(parts[0]), (0...24).contains(parts[1]) else { return nil }
            return (GuitarNote(string: parts[0], fret: parts[1]), value)
        }.sorted { $0.score.weight(at: Date()) > $1.score.weight(at: Date()) }
    }
    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FretNote/progress.json")
        let file = self.file
        if FileManager.default.fileExists(atPath: file.path) {
            do { progress = try JSONDecoder().decode([String: NoteProgress].self, from: Data(contentsOf: file)) }
            catch {
                canSave = false
                persistenceError = "学习记录读取失败，原文件已保留，本次不会覆盖：\(file.path)"
            }
        }
    }
    func start() {
        nextTask?.cancel()
        answered = 0; firstCorrect = 0; totalSeconds = 0
        showSummary = false; active = true
        nextExercise()
    }
    func end() {
        nextTask?.cancel()
        active = false
        showSummary = answered > 0
        feedback = "练习已暂停。已完成的音符已保存。"
        feedbackKind = 0
    }
    func nextExercise() {
        let previous = notes.last?.id
        let pool = ExerciseGenerator.pool(string: mode == .melody ? nil : string, lower: lowerFret, upper: upperFret, naturalsOnly: naturalsOnly)
        notes = ExerciseGenerator.make(pool: pool, count: mode == .melody ? min(melodyLength, 20 - answered) : 1, progress: progress, excluding: previous)
        index = 0; completed = false; hint = false; wrong = false
        began = Date(); ignoreUntil = Date().addingTimeInterval(0.15)
        feedback = notes.isEmpty ? "这个范围没有可练的音，请调整设置。" : "请弹奏目标音。"
        feedbackKind = 0
        if notes.isEmpty { active = false }
    }
    func reveal() { guard active, !completed else { return }; hint = true }
    func skip() {
        guard active, !completed, target != nil else { return }
        finishNote(correct: false, hinted: true)
        feedback = "已记为待复习，下次再试。"; feedbackKind = 0
    }
    func receive(_ midi: Int) {
        guard active, !completed, Date() >= ignoreUntil, let target else { return }
        if midi == target.midi {
            let clean = !wrong && !hint
            finishNote(correct: clean, hinted: hint)
            feedback = completed ? "本题完成。" : "正确，继续下一个音。"
            feedbackKind = 1
        } else {
            wrong = true
            feedback = "听到 \(GuitarNote.names[(midi % 12 + 12) % 12])\(midi / 12 - 1)，再试一次。"
            feedbackKind = -1
        }
    }
    private func finishNote(correct: Bool, hinted: Bool) {
        guard let target else { return }
        let seconds = Date().timeIntervalSince(began)
        var record = progress[target.id] ?? NoteProgress()
        record.record(correct: correct, seconds: seconds, hinted: hinted)
        progress[target.id] = record
        answered += 1; if correct { firstCorrect += 1 }
        totalSeconds += seconds
        save()
        index += 1; hint = false; wrong = false; began = Date()
        ignoreUntil = Date().addingTimeInterval(0.1)
        if index == notes.count {
            completed = true
            nextTask = Task { [weak self] in
                try? await Task.sleep(nanoseconds: 850_000_000)
                guard !Task.isCancelled, let self, self.active else { return }
                if self.answered >= 20 { self.end() } else { self.nextExercise() }
            }
        }
    }
    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(progress).write(to: file, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "记录保存失败：\(error.localizedDescription)" }
    }
}
