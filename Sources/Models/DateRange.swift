import Foundation

/// User-selectable time windows for the export.
enum DateRangeOption: String, CaseIterable, Identifiable {
    case last7Days
    case last30Days
    case last90Days
    case last365Days
    case allTime

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last7Days: return "7 days"
        case .last30Days: return "30 days"
        case .last90Days: return "90 days"
        case .last365Days: return "1 year"
        case .allTime: return "All time"
        }
    }

    var subtitle: String {
        switch self {
        case .last7Days: return "This week at a glance"
        case .last30Days: return "A month of trends"
        case .last90Days: return "A quarter of data"
        case .last365Days: return "Annual overview"
        case .allTime: return "Everything Health has"
        }
    }

    /// Returns the (start, end) interval for this option, anchored to now.
    func interval(now: Date = Date(), calendar: Calendar = .current) -> DateInterval {
        let end = now
        let start: Date
        switch self {
        case .last7Days:
            start = calendar.date(byAdding: .day, value: -7, to: end) ?? end
        case .last30Days:
            start = calendar.date(byAdding: .day, value: -30, to: end) ?? end
        case .last90Days:
            start = calendar.date(byAdding: .day, value: -90, to: end) ?? end
        case .last365Days:
            start = calendar.date(byAdding: .day, value: -365, to: end) ?? end
        case .allTime:
            // HealthKit data realistically never predates 2014 (first Apple Watch / iOS 8).
            start = calendar.date(from: DateComponents(year: 2014, month: 1, day: 1)) ?? end
        }
        return DateInterval(start: start, end: end)
    }

    var dayCount: Int {
        switch self {
        case .last7Days: return 7
        case .last30Days: return 30
        case .last90Days: return 90
        case .last365Days: return 365
        case .allTime: return 0 // computed from interval when needed
        }
    }
}
