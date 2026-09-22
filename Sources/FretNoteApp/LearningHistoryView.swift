import SwiftUI
import FretNoteCore

struct LearningHistoryView: View {
    @ObservedObject var practice: PracticeStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.interfaceScale) private var scale
    @Environment(\.colorScheme) private var scheme
    @Environment(\.colorSchemeContrast) private var contrast
    @State private var tab = 0
    @State private var page = 0
    private var palette: AppPalette { AppPalette(scheme: scheme, contrast: contrast) }
    private let pageSize = 3
    private var count: Int { tab == 0 ? practice.sessions.count : practice.weakNotes.count }
    private var pages: Int { max(1, (count + pageSize - 1) / pageSize) }
    private var safePage: Int { min(page, pages - 1) }
    private var attempts: Int { practice.progress.values.reduce(0) { $0 + $1.attempts } }
    private var correct: Int { practice.progress.values.reduce(0) { $0 + $1.firstCorrect } }
    private var seconds: Double { practice.progress.values.reduce(0) { $0 + $1.totalSeconds } }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("学习记录").font(.system(size: 22 * scale, weight: .medium))
            HStack(alignment: .top, spacing: 32) {
                metric("\(attempts)", "累计练习音符")
                metric(attempts == 0 ? "—" : "\(Int(Double(correct) / Double(attempts) * 100))%", "首次正确率")
                metric(attempts == 0 ? "—" : String(format: "%.1f 秒", seconds / Double(attempts)), "平均找音时间")
                Spacer(minLength: 0)
            }
            Divider()
            Picker("记录内容", selection: $tab) {
                Text("练习历史").tag(0)
                Text("优先复习").tag(1)
            }.pickerStyle(.segmented).labelsHidden()
                .onChange(of: tab) { _ in page = 0 }
            if count == 0 {
                VStack(spacing: 10) {
                    Image(systemName: "clock").font(.system(size: 28 * scale))
                    Text(tab == 0 ? "还没有练习历史" : "还没有待复习的音")
                    Text(tab == 0 ? "完成一个音就会自动记录；之前的统计已保留。" : "练习后，这里会显示需要多练的音。")
                        .font(.system(size: 12 * scale)).foregroundStyle(palette.muted)
                }.frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    if tab == 0 {
                        ForEach(Array(practice.sessions.dropFirst(safePage * pageSize).prefix(pageSize))) { session in
                            sessionRow(session)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                    } else {
                        ForEach(Array(practice.weakNotes.dropFirst(safePage * pageSize).prefix(pageSize)), id: \.note.id) { item in
                            noteRow(item.note, item.score)
                                .frame(maxHeight: .infinity, alignment: .center)
                        }
                    }
                    // Keep the final page's rows the same height as a full page.
                    ForEach(0..<max(0, pageSize - min(pageSize, count - safePage * pageSize)), id: \.self) { _ in
                        Color.clear.frame(maxHeight: .infinity)
                    }
                }.frame(maxHeight: .infinity)
            }
            Text(tab == 0 ? "用过提示、弹错后重试或跳过，均不计为首次正确。" : "按复习优先级排序；位置为题目参考，音高识别无法确认实际弦位。")
                .font(.system(size: 11 * scale)).foregroundStyle(palette.muted)
            Divider()
            HStack(spacing: 12) {
                Button { page = max(0, safePage - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(safePage == 0).accessibilityLabel("上一页")
                Text("\(safePage + 1) / \(pages)").monospacedDigit().foregroundStyle(palette.muted)
                Button { page = min(pages - 1, safePage + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(safePage + 1 >= pages).accessibilityLabel("下一页")
                Spacer()
                Button("完成") { dismiss() }.keyboardShortcut(.defaultAction)
            }.buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 780, height: 640)
        .font(.system(size: 13 * scale))
        .foregroundStyle(palette.ink).background(palette.background).tint(palette.ink)
    }

    private func metric(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(value).font(.system(size: 22 * scale)).monospacedDigit()
            Text(caption).font(.system(size: 11 * scale)).foregroundStyle(palette.muted)
        }
    }

    private func sessionRow(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(session.mode).fontWeight(.medium)
                Text(session.answered >= 20 ? "已完成" : (session.endedAt == nil ? "已保存" : "提前结束"))
                    .font(.system(size: 11 * scale)).foregroundStyle(palette.muted)
                Spacer()
                Text(session.startedAt.formatted(.dateTime.month().day().hour().minute()))
                    .font(.system(size: 11 * scale)).foregroundStyle(palette.muted)
                    .help(session.startedAt.formatted(date: .complete, time: .shortened))
            }
            Text(session.scope).font(.system(size: 11 * scale)).foregroundStyle(palette.muted)
            HStack {
                Text("\(session.answered) 音 · 首次正确 \(session.accuracy) · 平均 \(session.averageTime)")
                Spacer(minLength: 0)
                Text("提示 \(session.hints) · 跳过 \(session.skipped)")
            }.font(.system(size: 11 * scale)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteRow(_ note: GuitarNote, _ score: NoteProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("\(note.fullName) · \(note.string) 弦 \(note.fret) 品").fontWeight(.medium)
                Spacer()
                Text(score.due <= Date() ? "待复习" : "巩固中").foregroundStyle(palette.muted)
            }
            Text("练过 \(score.attempts) 次 · 首次正确 \(Int(score.accuracy * 100))% · 平均 \(String(format: "%.1f", score.totalSeconds / Double(max(1, score.attempts)))) 秒")
                .font(.system(size: 11 * scale)).foregroundStyle(palette.muted).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
