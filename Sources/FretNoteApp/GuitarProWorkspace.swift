import Foundation

@MainActor
final class GuitarProWorkspace: ObservableObject {
    struct Document: Codable, Identifiable {
        let id: UUID
        let sourceName: String
        let score: GuitarProScore
        var revision: UUID? = nil
    }
    private struct Snapshot: Codable {
        var documents: [Document]
        var selectedID: UUID?
    }
    @Published private(set) var documents: [Document] = []
    @Published private(set) var selectedID: UUID?
    @Published var error: String?
    private let file: URL?
    var selected: Document? { documents.first { $0.id == selectedID } }

    init(file: URL? = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
        .appendingPathComponent("FretNote/GuitarProWorkspace.json")) {
        self.file = file
        guard let file, FileManager.default.fileExists(atPath: file.path) else { return }
        do {
            let saved = try JSONDecoder().decode(Snapshot.self, from: Data(contentsOf: file))
            documents = saved.documents
            selectedID = saved.selectedID == nil || documents.contains(where: { $0.id == saved.selectedID }) ? saved.selectedID : documents.first?.id
        } catch { self.error = error.localizedDescription }
    }
    func add(score: GuitarProScore, sourceName: String) throws {
        let legacyIndex = documents.firstIndex { $0.sourceName == sourceName && $0.score.beats == nil }
        let document = Document(id: legacyIndex.map { documents[$0].id } ?? UUID(), sourceName: sourceName, score: score, revision: UUID())
        var next = documents
        if let legacyIndex { next[legacyIndex] = document } else { next.append(document) }
        try save(documents: next, selectedID: document.id)
        documents = next
        selectedID = document.id
    }
    func select(_ id: UUID?) {
        guard id == nil || documents.contains(where: { $0.id == id }) else { return }
        do {
            try save(documents: documents, selectedID: id)
            selectedID = id
        } catch { self.error = error.localizedDescription }
    }
    func close(_ id: UUID) {
        let next = documents.filter { $0.id != id }
        let selected = selectedID == id ? next.first?.id : selectedID
        do {
            try save(documents: next, selectedID: selected)
            documents = next
            selectedID = selected
        } catch { self.error = error.localizedDescription }
    }
    private func save(documents: [Document], selectedID: UUID?) throws {
        guard let file else { return }
        try FileManager.default.createDirectory(at: file.deletingLastPathComponent(), withIntermediateDirectories: true)
        try JSONEncoder().encode(Snapshot(documents: documents, selectedID: selectedID)).write(to: file, options: .atomic)
    }
}
