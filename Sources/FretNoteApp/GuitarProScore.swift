import Foundation
import JavaScriptCore
import CoreFoundation
import FretNoteCore

struct GuitarProScore: Codable, Sendable {
    let title: String
    let tempo: Double
    let barCount: Int
    let tracks: [Track]
    struct Track: Codable, Identifiable, Sendable {
        let id: Int
        let name: String
        let supported: Bool
        let frames: [Frame]
        let events: [MIDIEvent]
        func selection(from first: Int, through last: Int) -> [Frame] {
            var time = 0.0
            return frames.filter { $0.bar >= first && $0.bar <= last }.map { frame in
                let duration = frame.end - frame.start
                defer { time += duration }
                return Frame(start: time, end: time + duration, bar: frame.bar, notes: frame.notes)
            }
        }
    }
    struct MIDIEvent: Codable, Sendable, Equatable {
        let time: Double
        let kind: Int
        let channel: Int
        let key: Int
        let value: Int
        func at(_ time: Double) -> Self { .init(time: time, kind: kind, channel: channel, key: key, value: value) }
    }
    struct Frame: Codable, Sendable {
        let start: Double
        let end: Double
        let bar: Int
        let notes: [Note]
        var positions: [GuitarNote] { notes.map { GuitarNote(string: $0.string, fret: $0.fret) } }
    }
    struct Note: Codable, Sendable {
        let string: Int
        let fret: Int
        let bend: [Bend]
        let tie: Bool
        let slide: Bool
        let legato: Bool
    }
    struct Bend: Codable, Sendable { let offset: Double; let semitones: Double }

    enum ImportError: Error, LocalizedError {
        case invalid(String)
        var errorDescription: String? {
            if case .invalid(let message) = self { return message }; return nil
        }
    }
    /// A private JS VM on a background task: no browser, network or Python runtime.
    static func load(_ url: URL) throws -> GuitarProScore {
        let data = try Data(contentsOf: url)
        guard data.count <= 20_000_000 else { throw ImportError.invalid("文件太大（最大 20 MB）") }
        guard let context = JSContext(),
              let scriptURL = Bundle.module.url(forResource: "GuitarProImporter", withExtension: "js") else {
            throw ImportError.invalid("无法加载乐谱解析器")
        }
        let decode: @convention(block) ([UInt8], String) -> String = { bytes, name in
            let cf = CFStringConvertIANACharSetNameToEncoding(name as CFString)
            let encoding = cf == kCFStringEncodingInvalidId ? String.Encoding.utf8 : String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cf))
            return String(data: Data(bytes), encoding: encoding) ?? String(decoding: bytes, as: UTF8.self)
        }
        let encode: @convention(block) (String) -> [UInt8] = { Array($0.utf8) }
        context.setObject(decode, forKeyedSubscript: "decodeText" as NSString)
        context.setObject(encode, forKeyedSubscript: "encodeText" as NSString)
        context.evaluateScript("class TextDecoder { constructor(e='utf-8'){this.e=e;} decode(b){return decodeText(Array.from(b),this.e);} } class TextEncoder { encode(s){return new Uint8Array(encodeText(s));} }")
        context.evaluateScript("var console={debug:function(){},log:function(){},info:function(){},warn:function(){},error:function(){}};")
        context.evaluateScript(try String(contentsOf: scriptURL))
        if let exception = context.exception { throw ImportError.invalid(exception.toString()) }
        let result = context.objectForKeyedSubscript("FretNoteGP")?.invokeMethod("parse", withArguments: [Array(data)])
        if let exception = context.exception { throw ImportError.invalid(exception.toString()) }
        guard let json = result?.toString()?.data(using: .utf8) else { throw ImportError.invalid("无法读取 Guitar Pro 文件") }
        let score = try JSONDecoder().decode(Self.self, from: json)
        guard score.tracks.contains(where: \.supported) else {
            throw ImportError.invalid("没有可显示的音轨：需要标准调弦、无变调夹、最高 21 品的六弦吉他")
        }
        return score
    }
}
