import Foundation

/// Stress level bands, shared by the value label and the bar colours.
enum StressLevel { case low, moderate, elevated, high }

/// One hour's stress bucket for the intraday strip.
struct StressBucket: Identifiable {
    let hour: Date          // start of the clock hour
    let stress: Int?        // 0–100, nil = no heart-rate data that hour (gap)
    var id: Date { hour }
}

/// Intraday stress: a per-hour series over the last 24h plus the live "now"
/// reading. Computed from heart rate relative to your resting baseline — see
/// `StressAnalyzer` for the model and its caveats.
struct StressReport {
    let buckets: [StressBucket]     // chronological, earliest → latest (now)
    let now: Int?                   // realtime stress 0–100 (latest HR sample)
    let nowAt: Date?                // timestamp of that latest HR sample
    let restingHR: Double?          // baseline used for the mapping
    let currentHR: Double?          // latest HR, bpm
    let dayAverage: Int?            // mean stress across the buckets with data
    let updatedAt: Date

    var hasData: Bool { now != nil || buckets.contains { $0.stress != nil } }

    /// Word + level band for a 0–100 stress value.
    static func band(_ v: Int) -> (label: String, level: StressLevel) {
        switch v {
        case ..<30:   return ("Low", .low)
        case 30..<55: return ("Moderate", .moderate)
        case 55..<75: return ("Elevated", .elevated)
        default:      return ("High", .high)
        }
    }
}
