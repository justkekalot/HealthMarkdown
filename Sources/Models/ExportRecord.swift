import Foundation

/// Metadata for a single saved export. The Markdown body lives in a sibling
/// `.md` file named by `id`; this record is the index entry.
struct ExportRecord: Identifiable, Codable, Equatable {
    let id: UUID
    let createdAt: Date
    let mode: ExportMode
    let rangeTitle: String
    let dataPoints: Int
    let sectionCount: Int
    let fileName: String   // e.g. "<uuid>.md"

    static func == (lhs: ExportRecord, rhs: ExportRecord) -> Bool { lhs.id == rhs.id }
}
