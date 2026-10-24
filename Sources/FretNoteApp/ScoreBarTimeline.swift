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


}

struct ScoreBarTimeline: View, Localizable {
    @Environment(\.appLanguage) var language
    @Environment(\.interfaceScale) private var scale
    let segments: [ScoreBarSegment]
    let step: Int
    let seek: (Int) -> Void
    var tracks: [GuitarProScore.Track] = []
    var selectedTrackID: Int = 0
    var selectTrackBar: ((Int, Int) -> Void)? = nil
    var mutedTracks: Set<Int> = []
    var toggleMute: ((Int) -> Void)? = nil
    @State private var page = 0
    private var currentID: Int? { segments.last(where: { $0.id <= step })?.id }
    private var currentColumn: Int { segments.lastIndex(where: { $0.id <= step }) ?? 0 }
    private var rowLimit: Int { scale > 1.4 ? 4 : 6 }
    private var visibleTracks: [GuitarProScore.Track] { Array(tracks.dropFirst(page * rowLimit).prefix(rowLimit)) }
    private var rowHeight: CGFloat { 22 * scale }
    private var accent: Color { Color(red: 0.20, green: 0.85, blue: 0.96) }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if !tracks.isEmpty {
                VStack(spacing: 2) {
                    HStack {
                        Text(L("音轨"))
                        Spacer()
                        if tracks.count > rowLimit {
                            Button { page = max(0, page - 1) } label: { Image(systemName: "chevron.up") }.disabled(page == 0).accessibilityLabel(L("上一组音轨"))
                            Button { page += 1 } label: { Image(systemName: "chevron.down") }.disabled((page + 1) * rowLimit >= tracks.count).accessibilityLabel(L("下一组音轨"))
                        }
                    }.frame(height: 18 * scale)
                    ForEach(visibleTracks) { track in
                        HStack(spacing: 8) {
                            Button { toggleMute?(track.id) } label: {
                                Image(systemName: mutedTracks.contains(track.id) ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                    .frame(width: 20 * scale, height: rowHeight)
                            }.accessibilityLabel(L(mutedTracks.contains(track.id) ? "取消静音" : "静音") + " " + track.name)
                                .help(L(mutedTracks.contains(track.id) ? "取消静音" : "静音"))
                            Button { selectTrackBar?(track.id, currentColumn) } label: {
                                Text(track.name).lineLimit(1).frame(maxWidth: .infinity, alignment: .leading)
                                    .foregroundStyle(track.id == selectedTrackID ? Color.primary : Color.secondary)
                                    .frame(height: rowHeight).contentShape(Rectangle())
                            }.help(track.name)
                        }.opacity(mutedTracks.contains(track.id) ? 0.55 : 1)

                    }
                }.frame(width: 155 * scale)
            }
            GeometryReader { geometry in
                let width = min(48 * scale, max(26 * scale, (geometry.size.width - CGFloat(max(0, segments.count - 1)) * 2) / CGFloat(max(1, segments.count))))
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: true) {
                        HStack(spacing: 2) {
                            ForEach(Array(segments.enumerated()), id: \.element.id) { column, segment in
                                VStack(spacing: 2) {
                                    Text("\(segment.bar)").monospacedDigit().frame(height: 18 * scale)
                                    if tracks.isEmpty {
                                        cell(segment: segment, filled: segment.hasNotes, selected: true, width: width) { seek(segment.id) }
                                    } else {
                                        ForEach(visibleTracks) { track in
                                            cell(segment: segment,
                                                 filled: track.barActivity?.contains(segment.bar) ?? track.frames.contains { $0.bar == segment.bar && !$0.notes.isEmpty },
                                                 selected: track.id == selectedTrackID, width: width) {
                                                selectTrackBar?(track.id, column)
                                            }
                                        }
                                    }
                                }.frame(width: width).id(segment.id)
                            }
                        }.padding(.bottom, 10)
                    }
                    .onChange(of: currentID) { if let id = $0 { proxy.scrollTo(id) } }
                    .onAppear { if let currentID { proxy.scrollTo(currentID) } }
                }
            }
        }
        .font(.editorial(size: 11 * scale)).buttonStyle(.plain)
        .frame(height: 18 * scale + CGFloat(max(1, visibleTracks.count)) * (rowHeight + 2) + 12)
        .onChange(of: selectedTrackID) { id in
            if let index = tracks.firstIndex(where: { $0.id == id }) { page = index / rowLimit }
        }
    }

    private func cell(segment: ScoreBarSegment, filled: Bool, selected: Bool, width: CGFloat, action: @escaping () -> Void) -> some View {
        let current = segment.id == currentID
        return Button(action: action) {
            Rectangle()
                .fill(current ? accent.opacity(selected ? 0.8 : 0.3) : Color.primary.opacity(filled ? 0.16 : 0.025))
                .overlay(Rectangle().strokeBorder(current ? accent : Color.primary.opacity(0.18), lineWidth: current && selected ? 2 : 0.5))
                .frame(width: width, height: rowHeight)
        }
        .accessibilityLabel("\(L("小节")) \(segment.bar)")
        .accessibilityValue(current ? L("当前小节") : "")
        .help("\(L("跳到小节")) \(segment.bar)")
    }
}
