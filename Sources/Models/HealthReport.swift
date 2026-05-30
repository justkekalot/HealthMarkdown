import Foundation

/// Summary of a single quantity metric over the selected window.
struct QuantitySummary: Identifiable {
    let spec: QuantitySpec
    let total: Double?
    let average: Double?
    let dailyAverage: Double?   // total / days, for cumulative metrics
    let min: Double?
    let max: Double?
    let mostRecent: Double?
    let mostRecentDate: Date?
    let sampleCount: Int

    var id: String { spec.id }
    var hasData: Bool { sampleCount > 0 }
}

/// One night/segment of sleep, summarised.
struct SleepSummary {
    var totalAsleep: TimeInterval = 0
    var inBed: TimeInterval = 0
    var rem: TimeInterval = 0
    var core: TimeInterval = 0
    var deep: TimeInterval = 0
    var awake: TimeInterval = 0
    var nights: Int = 0
    var sampleCount: Int = 0

    var hasData: Bool { sampleCount > 0 }
    var averageAsleepPerNight: TimeInterval { nights > 0 ? totalAsleep / Double(nights) : 0 }
}

/// Mindfulness sessions summary.
struct MindfulSummary {
    var totalDuration: TimeInterval = 0
    var sessionCount: Int = 0
    var hasData: Bool { sessionCount > 0 }
}

/// A single workout.
struct WorkoutSummary: Identifiable {
    let id = UUID()
    let activityName: String
    let start: Date
    let duration: TimeInterval
    let energyKcal: Double?
    let distanceKm: Double?
}

/// Aggregated workouts.
struct WorkoutsSummary {
    var workouts: [WorkoutSummary] = []
    var totalEnergy: Double = 0
    var totalDistance: Double = 0
    var totalDuration: TimeInterval = 0
    var hasData: Bool { !workouts.isEmpty }
}

/// User characteristics (static profile data).
struct ProfileSummary {
    var dateOfBirth: DateComponents?
    var ageYears: Int?
    var biologicalSex: String?
    var bloodType: String?
    var skinType: String?

    var hasData: Bool {
        ageYears != nil || biologicalSex != nil || bloodType != nil || skinType != nil
    }
}

/// A single raw HealthKit sample (full export only): exact timestamp + value,
/// straight from the store with no bucketing or averaging.
struct RawSample {
    let start: Date
    let end: Date
    let value: Double
    let source: String?
}

/// Every raw sample for one quantity metric (full export only).
struct QuantityRawSeries: Identifiable {
    let spec: QuantitySpec
    let samples: [RawSample]   // chronological
    var id: String { spec.id }
    var hasData: Bool { !samples.isEmpty }
}

/// The complete report handed to the Markdown generator.
struct HealthReport {
    let generatedAt: Date
    let range: DateRangeOption
    let mode: ExportMode
    let interval: DateInterval
    var profile = ProfileSummary()
    var quantities: [QuantitySummary] = []
    var sleep = SleepSummary()
    var mindful = MindfulSummary()
    var workouts = WorkoutsSummary()
    /// Populated only when mode == .full — raw per-sample data.
    var rawSeries: [QuantityRawSeries] = []
    /// Total raw samples across all metrics (full export).
    var rawSampleCount: Int { rawSeries.reduce(0) { $0 + $1.samples.count } }

    var sectionsWithData: [HealthSection] {
        var present = Set<HealthSection>()
        for q in quantities where q.hasData { present.insert(q.spec.section) }
        if sleep.hasData { present.insert(.sleep) }
        if mindful.hasData { present.insert(.mindfulness) }
        if workouts.hasData { present.insert(.workouts) }
        if profile.hasData { present.insert(.profile) }
        return HealthSection.allCases.filter { present.contains($0) }
    }

    var totalDataPoints: Int {
        quantities.reduce(0) { $0 + $1.sampleCount }
            + sleep.sampleCount
            + mindful.sessionCount
            + workouts.workouts.count
    }
}
