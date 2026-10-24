import SwiftUI

/// Consecutive playback occurrences, so repeated bars retain their own cells.
struct ScoreBarSegment: Identifiable {
    let id: Int
    let bar: Int
    let start: Double
    var end: Double
    var hasNotes: Bool

    static func make(frames: [GuitarProScore.Frame]) -> [Self] {
        var result: [Self] = []
        for (index, frame) in frames.enumerated() {
            if let last = result.last, last.bar == frame.bar {
                result[result.count - 1].end = frame.end
                result[result.count - 1].hasNotes = last.hasNotes || !frame.notes.isEmpty
            } else {
                result.append(Self(id: index, bar: frame.bar, start: frame.start,
                                   end: frame.end, hasNotes: !frame.notes.isEmpty))
            }
        }
        return result
    }

    func progress(at time: Double) -> Double {
        min(1, max(0, (time - start) / max(0.001, end - start)))
    }
}

struct ScoreBarTimeline: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.interfaceScale) private var scale
    let segments: [ScoreBarSegment]
    let step: Int
    /// Score time, before playback speed is applied.
    let position: Double
    let seek: (Int) -> Void

    private var currentID: Int? { segments.last(where: { $0.id <= step })?.id }
    private var accent: Color { Color(red: 0.20, green: 0.85, blue: 0.96) }

    var body: some View {
        GeometryReader { geometry in
            let cellWidth = min(48 * scale, max(30 * scale, (geometry.size.width - CGFloat(max(0, segments.count - 1)) * 2) / CGFloat(max(1, segments.count))))
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 2) {
                        ForEach(segments) { segment in
                            let current = segment.id == currentID
                            let past = segment.id < (currentID ?? 0)
                            Button { seek(segment.id) } label: {
                                VStack(spacing: 5) {
                                    Text("\(segment.bar)")
                                        .font(.editorial(size: 11 * scale))
                                        .monospacedDigit()
                                        .foregroundStyle(current ? Color.primary : Color.secondary)
                                    ZStack(alignment: .leading) {
                                        Rectangle().fill(current ? accent.opacity(0.25) : Color.primary.opacity(segment.hasNotes ? (past ? 0.22 : 0.11) : 0.025))
                                        if current {
                                            Rectangle().fill(accent.opacity(0.5))
                                                .frame(width: cellWidth * segment.progress(at: position))
                                            Rectangle().fill(Color.primary)
                                                .frame(width: 2)
                                                .offset(x: max(0, (cellWidth - 2) * segment.progress(at: position)))
                                        }
                                        Rectangle().strokeBorder(current ? accent : Color.primary.opacity(0.2), lineWidth: current ? 2 : 0.5)
                                    }.frame(height: 24 * scale)
                                }
                                .frame(width: cellWidth)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("\(L("小节")) \(segment.bar)")
                            .accessibilityValue(current ? L("当前小节") : "")
                            .help("\(L("跳到小节")) \(segment.bar)")
                            .id(segment.id)
                        }
                    }.padding(.bottom, 10)
                }
                .onChange(of: currentID) { id in
                    // Reveal only when outside the viewport; never delay audio playback.
                    if let id { proxy.scrollTo(id) }
                }
                .onAppear { if let currentID { proxy.scrollTo(currentID) } }
            }
        }.frame(height: 50 * scale)
    }
}
