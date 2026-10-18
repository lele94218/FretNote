import SwiftUI
import FretNoteCore

struct LearningHistoryView: View, Localizable {
    @Environment(\.appLanguage) var language
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
            Text(L("学习记录")).font(.editorial(size: 22 * scale, weight: .medium))
            HStack(alignment: .top, spacing: 32) {
                metric("\(attempts)", L("累计练习音符"))
                metric(attempts == 0 ? "—" : "\(Int(Double(correct) / Double(attempts) * 100))%", L("首次正确率"))
                metric(attempts == 0 ? "—" : String(format: L("%.1f 秒"), seconds / Double(attempts)), L("平均找音时间"))
                Spacer(minLength: 0)
            }
            Text(L("三音练习 \(practice.sessions.filter { $0.questionCount != nil }.reduce(0) { $0 + $1.answered }) 题 · 单独按完整题目统计"))
                .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            Divider()
            Picker(L("记录内容"), selection: $tab) {
                Text(L("练习历史")).tag(0)
                Text(L("优先复习")).tag(1)
            }.pickerStyle(.segmented).labelsHidden()
                .onChange(of: tab) { _ in page = 0 }
            if count == 0 {
                VStack(spacing: 10) {
                    Image(systemName: "clock").font(.system(size: 28 * scale))
                    Text(L(tab == 0 ? L("还没有练习历史") : L("还没有待复习的音")))
                    Text(L(tab == 0 ? L("完成一个音就会自动记录；之前的统计已保留。") : L("练习后，这里会显示需要多练的音。")))
                        .font(.editorial(size: 12 * scale)).foregroundStyle(palette.muted)
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
            Text(L(tab == 0 ? L("用过提示、弹错后重试或跳过，均不计为首次正确。") : L("按复习优先级排序；位置为题目参考，音高识别无法确认实际弦位。")))
                .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            Divider()
            HStack(spacing: 12) {
                Button { page = max(0, safePage - 1) } label: { Image(systemName: "chevron.left") }
                    .disabled(safePage == 0).accessibilityLabel(L("上一页"))
                Text(L("\(safePage + 1) / \(pages)")).monospacedDigit().foregroundStyle(palette.muted)
                Button { page = min(pages - 1, safePage + 1) } label: { Image(systemName: "chevron.right") }
                    .disabled(safePage + 1 >= pages).accessibilityLabel(L("下一页"))
                Spacer()
                Button(L("完成")) { dismiss() }.keyboardShortcut(.defaultAction)
            }.buttonStyle(.bordered)
        }
        .padding(20)
        .frame(width: 780, height: 640)
        .font(.editorial(size: 13 * scale))
        .foregroundStyle(palette.ink).background(palette.background).tint(palette.ink)
    }

    private func metric(_ value: String, _ caption: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(L(value)).font(.editorial(size: 22 * scale)).monospacedDigit()
            Text(L(caption)).font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
        }
    }

    private func sessionRow(_ session: LearningSession) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(L(session.mode)).fontWeight(.medium)
                Text(L(session.answered >= (session.questionCount ?? 20) ? L("已完成") : (session.endedAt == nil ? L("已保存") : L("提前结束"))))
                    .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
                Spacer()
                Text(L(session.startedAt.formatted(.dateTime.month().day().hour().minute().locale(language.locale))))
                    .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
                    .help(session.startedAt.formatted(.dateTime.year().month(.wide).day().hour().minute().locale(language.locale)))
            }
            Text(L(session.scope)).font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted)
            HStack {
                Text(L("\(session.answered) \(session.unit) · 首次正确 \(session.accuracy) · 平均 \(session.averageTime)"))
                Spacer(minLength: 0)
                Text(L("提示 \(session.hints) · 跳过 \(session.skipped)"))
            }.font(.editorial(size: 11 * scale)).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func noteRow(_ note: GuitarNote, _ score: NoteProgress) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L("\(note.fullName) · \(note.string) 弦 \(note.fret) 品")).fontWeight(.medium)
                Spacer()
                Text(L(score.due <= Date() ? L("待复习") : L("巩固中"))).foregroundStyle(palette.muted)
            }
            Text(L("练过 \(score.attempts) 次 · 首次正确 \(Int(score.accuracy * 100))% · 平均 \(String(format: "%.1f", score.totalSeconds / Double(max(1, score.attempts)))) 秒"))
                .font(.editorial(size: 11 * scale)).foregroundStyle(palette.muted).monospacedDigit()
        }.frame(maxWidth: .infinity, alignment: .leading)
    }
}
