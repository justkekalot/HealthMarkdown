import Foundation

/// Direction of a day-over-day change, interpreted for recovery (higher isn't
/// always better — e.g. resting HR up is bad).
enum TrendDirection {
    case better, worse, flat, unknown
}

/// One recovery metric compared today vs the prior day.
struct RecoveryMetric: Identifiable {
    let key: String
    let title: String
    let symbol: String
    let todayText: String       // formatted value, e.g. "61 ms"
    let yesterdayText: String?
    let deltaText: String?      // e.g. "+6 ms", "−4 bpm"
    let trend: TrendDirection
    var id: String { key }
}

/// The morning recovery snapshot the on-device model narrates.
struct RecoveryReport {
    let date: Date
    /// 0–100 composite recovery score, or nil if not enough data.
    let score: Int?
    let headline: String        // short status, e.g. "Well recovered"
    let metrics: [RecoveryMetric]
    /// True if we lacked the inputs to say anything useful.
    var hasData: Bool { score != nil || !metrics.isEmpty }
}
