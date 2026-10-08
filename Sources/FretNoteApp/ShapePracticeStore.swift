import Foundation
import FretNoteCore

@MainActor
final class ShapePracticeStore: ObservableObject {
    @Published var practicing = false
    @Published private(set) var active = false
    @Published private(set) var questions: [LearningExample] = []
    @Published private(set) var questionIndex = 0
    @Published private(set) var noteIndex = 0
    @Published private(set) var revealed = false
    @Published private(set) var completed = false
    @Published private(set) var feedback = "点击开始练习。"
    @Published private(set) var session: LearningSession?
    private var arpeggio = false
    private var wrong = false
    private var began = Date()
    private var quietSince: Date?
    private var armed = false
    var question: LearningExample? { questions.indices.contains(questionIndex) ? questions[questionIndex] : nil }
    var hasNext: Bool { questionIndex + 1 < questions.count }
    func start(catalog: [LearningExample], arpeggio: Bool, name: String, shell: Bool) {
        guard !active, !catalog.isEmpty else { return }
        // Equivalent sounding paths cannot be distinguished by audio. Ask once per voicing.
        var seen = Set<[Int]>()
        questions = Array(catalog.shuffled().filter { seen.insert($0.shape.tones.map(\.note.midi)).inserted }.prefix(10))
        self.arpeggio = arpeggio
        questionIndex = 0
        session = LearningSession(mode: (arpeggio ? "琶音练习" : "和弦练习") + (shell ? " · 137" : " · 135"), scope: name)
        session?.questionCount = questions.count
        active = true; practicing = true
        prepare()
    }
    private func prepare() {
        noteIndex = 0; revealed = false; completed = false; wrong = false
        armed = false; quietSince = nil; began = Date()
        feedback = "先止音，再弹奏。"
    }
    func observeLevel(_ rms: Double, gate: Double, now: Date = Date()) {
        guard active, !completed, !armed else { return }
        if rms < gate {
            if quietSince == nil { quietSince = now }
            if now.timeIntervalSince(quietSince ?? now) >= 0.15 {
                armed = true
                feedback = arpeggio ? "依次弹奏三个音，注意止音。" : "同时拨响或扫过三个音，并保持延音。"
            }
        } else { quietSince = nil }
    }
    func receive(note: Int, records: PracticeStore) {
        guard active, arpeggio, armed, !completed, let question,
              question.shape.tones.indices.contains(noteIndex) else { return }
        if note == question.shape.tones[noteIndex].note.midi {
            noteIndex += 1
            if noteIndex == 3 { finish(skipped: false, records: records) }
            else { feedback = "第 \(noteIndex) 音正确，继续。" }
        } else {
            wrong = true
            feedback = "听到 \(GuitarNote.names[(note % 12 + 12) % 12])\(note / 12 - 1)，重试第 \(noteIndex + 1) 音。"
        }
    }
    func receive(chord: [Int], records: PracticeStore) {
        guard active, !arpeggio, armed, !completed, let question else { return }
        if chord.sorted() == question.shape.tones.map(\.note.midi).sorted() {
            finish(skipped: false, records: records)
        } else {
            wrong = true
            feedback = "听到的音高组合不符，请止音后重试。"
        }
    }
    func reveal() { guard active, !completed else { return }; revealed = true }
    func skip(records: PracticeStore) { guard active, !completed else { return }; finish(skipped: true, records: records) }
    private func finish(skipped: Bool, records: PracticeStore) {
        guard let question, var current = session else { return }
        completed = true
        current.answered += 1
        let first = !wrong && !revealed && !skipped
        if first { current.firstCorrect += 1 }
        if revealed { current.hints += 1 }
        if skipped { current.skipped += 1 }
        let seconds = Date().timeIntervalSince(began)
        current.totalSeconds += seconds
        if current.shapeResults == nil { current.shapeResults = [] }
        current.shapeResults?.append(ShapeResult(midis: question.shape.tones.map(\.note.midi),
            strings: question.shape.tones.map(\.note.string), frets: question.shape.tones.map(\.note.fret),
            degrees: question.shape.tones.map(\.degree), path: question.label,
            firstCorrect: first, hinted: revealed, skipped: skipped, seconds: seconds))
        session = current
        records.recordShapeSession(current)
        feedback = skipped ? "已跳过，查看参考指型。" : (arpeggio ? "三个音的音高与顺序正确。" : "三个目标音已同时检出。")
    }
    func next() { guard active, completed, hasNext else { return }; questionIndex += 1; prepare() }
    func end(records: PracticeStore) {
        if var current = session, active, current.answered > 0 {
            current.endedAt = Date(); session = current
            records.recordShapeSession(current)
        }
        active = false
    }
    func clear() {
        guard !active else { return }
        questions = []; questionIndex = 0; noteIndex = 0
        session = nil; completed = false; revealed = false
    }
    func reset(records: PracticeStore, audio: AudioInput) {
        end(records: records)
        practicing = false
        clear()
        audio.learningMode = true
        audio.chordMode = false
    }
}
