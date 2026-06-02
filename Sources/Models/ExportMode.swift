import Foundation

/// Which flavour of export to generate.
enum ExportMode: String, CaseIterable, Identifiable, Codable {
    case quick   // aggregated summary — totals, averages, latest
    case full    // everything: aggregated summary + every raw sample
    case raw     // raw samples only, no aggregation

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quick: return "Quick"
        case .full: return "Full"
        case .raw: return "Raw"
        }
    }

    var subtitle: String {
        switch self {
        case .quick: return "Aggregated summary — totals, averages & latest readings"
        case .full: return "Everything — the summary plus every raw sample"
        case .raw: return "Raw samples only — every measurement, no summary or aggregation"
        }
    }

    /// Two-word descriptor for the compact selector card.
    var shortTag: String {
        switch self {
        case .quick: return "Summary"
        case .full: return "Summary + raw"
        case .raw: return "Raw only"
        }
    }

    var symbol: String {
        switch self {
        case .quick: return "bolt.fill"
        case .full: return "tray.full.fill"
        case .raw: return "circle.grid.3x3.fill"
        }
    }

    /// Does this mode read raw per-sample data?
    var includesRaw: Bool { self == .full || self == .raw }

    /// Does this mode emit the aggregated summary sections?
    var includesSummary: Bool { self == .quick || self == .full }
}
