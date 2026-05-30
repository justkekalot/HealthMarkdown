import Foundation

/// Which flavour of export to generate.
enum ExportMode: String, CaseIterable, Identifiable, Codable {
    case quick   // aggregated summary — totals, averages, latest
    case full    // everything: aggregates + day-by-day breakdown of every metric

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .full: return "Full"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Aggregated summary — totals, averages & latest readings"
        case .full: return "Everything — aggregates plus a day-by-day breakdown of every metric"
        }
    }

    /// Two-word descriptor for the compact selector card.
    var shortTag: String {
        switch self {
        case .quick: return "Summary"
        case .full: return "Every day"
        }
    }

    var symbol: String {
        switch self {
        case .quick: return "bolt.fill"
        case .full: return "tray.full.fill"
        }
    }
}
