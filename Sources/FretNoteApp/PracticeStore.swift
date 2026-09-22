import Foundation
import FretNoteCore

@MainActor
final class PracticeStore: ObservableObject {
    static let maximumFret = 21
    @Published var mode: PracticeMode = .names
    @Published var string = 1
    @Published private(set) var selectedStrings: Set<Int> = [1]
    func setString(_ number: Int, selected: Bool) {
        guard !active, (1...6).contains(number) else { return }
        if selected { selectedStrings.insert(number) }
        else if selectedStrings.count > 1 { selectedStrings.remove(number) }
        notes = []
        hint = false
    }
    var currentString: Int {
        mode == .names ? (target ?? notes.last)?.string ?? selectedStrings.sorted().first ?? 1 : string
    }
    var selectedStringLabel: String {
        selectedStrings.sorted().map(String.init).joined(separator: "、") + " 弦"
    }
    @Published var lowerFret = 1 {
        didSet {
            let bounded = min(max(customRange ? 0 : 1, lowerFret), customRange ? Self.maximumFret : Self.maximumFret - 3)
            if lowerFret != bounded { lowerFret = bounded }
            customUpperFret = min(max(customUpperFret, lowerFret), min(Self.maximumFret, lowerFret + 5))
        }
    }
    @Published var customRange = false {
        didSet {
            if !customRange { lowerFret = min(max(1, lowerFret), Self.maximumFret - 3) }
            customUpperFret = min(Self.maximumFret, lowerFret + 3)
        }
    }
    @Published private var customUpperFret = 4
    var upperFret: Int {
        get { customRange ? customUpperFret : lowerFret + 3 }
        set { customUpperFret = min(max(newValue, lowerFret), min(Self.maximumFret, lowerFret + 5)) }
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
    @Published private(set) var sessions: [LearningSession] = []
    private var session: LearningSession?
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
            guard parts.count == 2, (1...6).contains(parts[0]), (0...Self.maximumFret).contains(parts[1]) else { return nil }
            return (GuitarNote(string: parts[0], fret: parts[1]), value)
        }.sorted { $0.score.weight(at: Date()) > $1.score.weight(at: Date()) }
    }
    init(file: URL? = nil) {
        self.file = file ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FretNote/progress.json")
        let file = self.file
        if FileManager.default.fileExists(atPath: file.path) {
            do {
                let data = try Data(contentsOf: file)
                let decoder = JSONDecoder()
                if let archive = try? decoder.decode(LearningArchive.self, from: data) {
                    guard archive.version == 1 else { throw CocoaError(.coderReadCorrupt) }
                    progress = archive.progress
                    sessions = archive.sessions
                } else {
                    progress = try decoder.decode([String: NoteProgress].self, from: data)
                }
            }
            catch {
                canSave = false
                persistenceError = "学习记录读取失败，原文件已保留，本次不会覆盖：\(file.path)"
            }
        }
    }
    func start() {
        if active { end() }
        session = LearningSession(mode: mode.rawValue, scope: (mode == .names ? "\(selectedStringLabel) · 0–21 品" : "六根弦 · \(lowerFret)–\(upperFret) 品") + (naturalsOnly ? " · 自然音" : " · 全部音"))
        nextTask?.cancel()
        answered = 0; firstCorrect = 0; totalSeconds = 0
        showSummary = false; active = true
        nextExercise()
    }
    func end() {
        nextTask?.cancel()
        active = false
        if var current = session, current.answered > 0 {
            current.endedAt = Date()
            updateSession(current)
            save()
        }
        session = nil
        showSummary = answered > 0
        feedback = "练习已暂停。已完成的音符已保存。"
        feedbackKind = 0
    }
    var exercisePool: [GuitarNote] {
        ExerciseGenerator.pool(string: nil,
                               lower: mode == .names ? 0 : lowerFret,
                               upper: mode == .names ? Self.maximumFret : upperFret,
                               naturalsOnly: naturalsOnly)
            .filter { mode != .names || selectedStrings.contains($0.string) }
    }
    func nextExercise() {
        let previous = notes.last?.id
        var pool = exercisePool
        if mode == .names, selectedStrings.count > 1, let previousString = notes.last?.string {
            pool = pool.filter { $0.string != previousString }
        }
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
        finishNote(correct: false, hinted: hint, skipped: true)
        feedback = "已记为待复习，下次再试。"; feedbackKind = 0
    }
    func receive(_ midi: Int) {
        guard active, !completed, Date() >= ignoreUntil, let target else { return }
        let playedFret = midi - GuitarNote.openMIDI[target.string - 1]
        let correct = mode == .names
            ? (0...Self.maximumFret).contains(playedFret) && midi % 12 == target.midi % 12
            : midi == target.midi
        if correct {
            if mode == .names {
                // Credit the sounding octave on the requested string, not a hidden target octave.
                notes[index] = GuitarNote(string: target.string, fret: playedFret)
            }
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
    private func finishNote(correct: Bool, hinted: Bool, skipped: Bool = false) {
        guard let target else { return }
        let seconds = Date().timeIntervalSince(began)
        var record = progress[target.id] ?? NoteProgress()
        record.record(correct: correct, seconds: seconds, hinted: hinted)
        progress[target.id] = record
        answered += 1; if correct { firstCorrect += 1 }
        totalSeconds += seconds
        if var current = session {
            current.answered += 1
            if correct { current.firstCorrect += 1 }
            if hinted { current.hints += 1 }
            if skipped { current.skipped += 1 }
            current.totalSeconds += seconds
            session = current
            updateSession(current)
        }
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
    private func updateSession(_ current: LearningSession) {
        if let index = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[index] = current
        } else { sessions.insert(current, at: 0) }
    }
    private func save() {
        guard canSave else { return }
        do {
            try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
            let encoder = JSONEncoder(); encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(LearningArchive(progress: progress, sessions: sessions)).write(to: file, options: .atomic)
            persistenceError = nil
        } catch { persistenceError = "记录保存失败：\(error.localizedDescription)" }
    }
}
