import Foundation
import Combine

/// Persists generated Markdown exports to the app's Documents directory and
/// maintains a JSON index so the History tab can list, open, and delete them.
@MainActor
final class ExportStore: ObservableObject {
    @Published private(set) var records: [ExportRecord] = []

    private let fm = FileManager.default

    private var dir: URL {
        let base = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let exports = base.appendingPathComponent("Exports", isDirectory: true)
        if !fm.fileExists(atPath: exports.path) {
            try? fm.createDirectory(at: exports, withIntermediateDirectories: true)
        }
        return exports
    }

    private var indexURL: URL { dir.appendingPathComponent("index.json") }

    init() { load() }

    // MARK: - Loading

    func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder.health.decode([ExportRecord].self, from: data) else {
            records = []
            return
        }
        records = decoded.sorted { $0.createdAt > $1.createdAt }
    }

    private func persistIndex() {
        guard let data = try? JSONEncoder.health.encode(records) else { return }
        try? data.write(to: indexURL, options: .atomic)
    }

    // MARK: - Saving

    /// Saves a markdown body + metadata, returns the new record.
    @discardableResult
    func save(report: HealthReport, markdown: String) -> ExportRecord {
        let id = UUID()
        let fileName = "\(id.uuidString).md"
        let fileURL = dir.appendingPathComponent(fileName)
        try? markdown.data(using: .utf8)?.write(to: fileURL, options: .atomic)

        let record = ExportRecord(
            id: id,
            createdAt: report.generatedAt,
            mode: report.mode,
            rangeTitle: report.range.title,
            dataPoints: report.totalDataPoints,
            sectionCount: report.sectionsWithData.count,
            fileName: fileName
        )
        records.insert(record, at: 0)
        persistIndex()
        return record
    }

    // MARK: - Reading

    func markdown(for record: ExportRecord) -> String {
        let url = dir.appendingPathComponent(record.fileName)
        return (try? String(contentsOf: url, encoding: .utf8)) ?? "_Export file is missing._"
    }

    func fileURL(for record: ExportRecord) -> URL {
        dir.appendingPathComponent(record.fileName)
    }

    // MARK: - Deleting

    func delete(_ record: ExportRecord) {
        try? fm.removeItem(at: dir.appendingPathComponent(record.fileName))
        records.removeAll { $0.id == record.id }
        persistIndex()
    }

    func delete(at offsets: IndexSet) {
        let toRemove = offsets.map { records[$0] }
        for record in toRemove {
            try? fm.removeItem(at: dir.appendingPathComponent(record.fileName))
        }
        records.remove(atOffsets: offsets)
        persistIndex()
    }
}

extension JSONEncoder {
    static var health: JSONEncoder {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.prettyPrinted]
        return e
    }
}

extension JSONDecoder {
    static var health: JSONDecoder {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }
}
