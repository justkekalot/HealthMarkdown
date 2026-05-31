import Foundation

/// User-selectable time windows for the export.
enum DateRangeOption: String, CaseIterable, Identifiable {
    case last24Hours
    case yesterday
    case last7Days
    case last30Days
    case last90Days
    case last365Days
    case allTime
    case custom

    var id: String { rawValue }

    var title: String {
        switch self {
        case .last24Hours: return "24 hours"
        case .yesterday: return "Yesterday"
        case .last7Days: return "7 days"
        case .last30Days: return "30 days"
        case .last90Days: return "90 days"
        case .last365Days: return "1 year"
        case .allTime: return "All time"
        case .custom: return "Custom"
        }
    }

    var subtitle: String {
        switch self {
        case .last24Hours: return "The last 24 hours"
        case .yesterday: return "The full previous calendar day"
        case .last7Days: return "This week at a glance"
        case .last30Days: return "A month of trends"
        case .last90Days: return "A quarter of data"
        case .last365Days: return "Annual overview"
        case .allTime: return "Everything Health has"
        case .custom: return "Pick your own start & end"
        }
    }

    /// Whether this option needs an explicit start/end chosen by the user.
    var isCustom: Bool { self == .custom }

    /// Returns the (start, end) interval. For `.custom`, `customInterval` is used
    /// (falling back to the last 24h if somehow absent).
    func interval(now: Date = Date(), calendar: Calendar = .current, customInterval: DateInterval? = nil) -> DateInterval {
        let end = now
        switch self {
        case .last24Hours:
            let start = calendar.date(byAdding: .hour, value: -24, to: end) ?? end
            return DateInterval(start: start, end: end)
        case .yesterday:
            let startOfToday = calendar.startOfDay(for: end)
            let startOfYesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
            return DateInterval(start: startOfYesterday, end: startOfToday)
        case .last7Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -7, to: end) ?? end, end: end)
        case .last30Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -30, to: end) ?? end, end: end)
        case .last90Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -90, to: end) ?? end, end: end)
        case .last365Days:
            return DateInterval(start: calendar.date(byAdding: .day, value: -365, to: end) ?? end, end: end)
        case .allTime:
            // HealthKit data realistically never predates 2014 (first Apple Watch / iOS 8).
            let start = calendar.date(from: DateComponents(year: 2014, month: 1, day: 1)) ?? end
            return DateInterval(start: start, end: end)
        case .custom:
            return customInterval ?? DateInterval(start: calendar.date(byAdding: .hour, value: -24, to: end) ?? end, end: end)
        }
    }
}
