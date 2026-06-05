import Foundation

/// Whether a saved export came from the Health screen or the Workouts screen.
enum ExportKind: String, Codable { case health, workout }

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
    /// nil on records saved before workout exports existed → treat as .health.
    var kind: ExportKind? = nil
    /// For workout exports: which activities are inside, e.g. "Running ×3, Walking".
    var contents: String? = nil

    var isWorkout: Bool { kind == .workout }

    static func == (lhs: ExportRecord, rhs: ExportRecord) -> Bool { lhs.id == rhs.id }
}
