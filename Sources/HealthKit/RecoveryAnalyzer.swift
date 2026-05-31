import Foundation
import HealthKit

/// Computes a morning recovery snapshot from the last two nights/days of data.
///
/// This is deterministic, on-device math (no model) — the LLM narrates on top of
/// it. Recovery leans on the signals sports-science apps use: sleep duration,
/// HRV (SDNN), and resting heart rate, each compared day-over-day.
enum RecoveryAnalyzer {

    /// Average of a discrete quantity over an interval (e.g. resting HR, HRV).
    private static func avg(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit, interval: DateInterval) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .discreteAverage) { _, r, _ in
                cont.resume(returning: r?.averageQuantity()?.doubleValue(for: unit))
            }
            store.execute(q)
        }
    }

    /// Total asleep time (seconds) for sleep sessions overlapping an interval.
    private static func asleep(_ store: HKHealthStore, interval: DateInterval) async -> Double? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])
        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, _ in
                cont.resume(returning: (s as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        guard !samples.isEmpty else { return nil }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        ]
        let total = samples
            .filter { asleepValues.contains($0.value) }
            .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return total > 0 ? total : nil
    }

    /// Build the report. `now` is injectable for testing.
    static func build(store: HKHealthStore, now: Date = Date(), calendar: Calendar = .current) async -> RecoveryReport {
        // "Last night" = the 12h ending this morning; "night before" = prior 24h slice.
        let todayNight = DateInterval(start: calendar.date(byAdding: .hour, value: -14, to: now) ?? now, end: now)
        let yChunkEnd = calendar.date(byAdding: .day, value: -1, to: now) ?? now
        let yesterdayNight = DateInterval(start: calendar.date(byAdding: .hour, value: -14, to: yChunkEnd) ?? yChunkEnd, end: yChunkEnd)

        let hrvUnit = HKUnit.secondUnit(with: .milli)
        let bpm = HKUnit.count().unitDivided(by: .minute())

        async let hrvT = avg(store, .heartRateVariabilitySDNN, unit: hrvUnit, interval: todayNight)
        async let hrvY = avg(store, .heartRateVariabilitySDNN, unit: hrvUnit, interval: yesterdayNight)
        async let rhrT = avg(store, .restingHeartRate, unit: bpm, interval: todayNight)
        async let rhrY = avg(store, .restingHeartRate, unit: bpm, interval: yesterdayNight)
        async let slpT = asleep(store, interval: todayNight)
        async let slpY = asleep(store, interval: yesterdayNight)

        let hrvToday = await hrvT, hrvYest = await hrvY
        let rhrToday = await rhrT, rhrYest = await rhrY
        let sleepToday = await slpT, sleepYest = await slpY

        var metrics: [RecoveryMetric] = []
        var scoreParts: [Double] = []

        // HRV — higher is better.
        if let t = hrvToday {
            let trend = trendHigherBetter(t, hrvYest, tolerance: 3)
            metrics.append(.init(key: "hrv", title: "HRV (SDNN)", symbol: "waveform.path.ecg",
                                 todayText: "\(Int(t)) ms",
                                 yesterdayText: hrvYest.map { "\(Int($0)) ms" },
                                 deltaText: deltaText(t, hrvYest, unit: "ms"),
                                 trend: trend))
            if let y = hrvYest, y > 0 { scoreParts.append(clamp((t / y) * 50)) }
        }

        // Resting HR — lower is better.
        if let t = rhrToday {
            let trend = trendLowerBetter(t, rhrYest, tolerance: 2)
            metrics.append(.init(key: "rhr", title: "Resting heart rate", symbol: "heart.fill",
                                 todayText: "\(Int(t)) bpm",
                                 yesterdayText: rhrYest.map { "\(Int($0)) bpm" },
                                 deltaText: deltaText(t, rhrYest, unit: "bpm"),
                                 trend: trend))
            if let y = rhrYest, t > 0 { scoreParts.append(clamp((y / t) * 50)) }
        }

        // Sleep — more is better, target ~8h.
        if let t = sleepToday {
            let trend = trendHigherBetter(t, sleepYest, tolerance: 20 * 60)
            metrics.append(.init(key: "sleep", title: "Time asleep", symbol: "bed.double.fill",
                                 todayText: Fmt.duration(t),
                                 yesterdayText: sleepYest.map { Fmt.duration($0) },
                                 deltaText: sleepDelta(t, sleepYest),
                                 trend: trend))
            scoreParts.append(clamp((t / (8 * 3600)) * 100))
        }

        let score: Int? = scoreParts.isEmpty ? nil : Int((scoreParts.reduce(0,+) / Double(scoreParts.count)).rounded())
        let headline = headline(for: score, metrics: metrics)
        return RecoveryReport(date: now, score: score, headline: headline, metrics: metrics)
    }

    // MARK: - Helpers

    private static func clamp(_ v: Double) -> Double { min(100, max(0, v)) }

    private static func trendHigherBetter(_ t: Double, _ y: Double?, tolerance: Double) -> TrendDirection {
        guard let y else { return .unknown }
        if t > y + tolerance { return .better }
        if t < y - tolerance { return .worse }
        return .flat
    }

    private static func trendLowerBetter(_ t: Double, _ y: Double?, tolerance: Double) -> TrendDirection {
        guard let y else { return .unknown }
        if t < y - tolerance { return .better }
        if t > y + tolerance { return .worse }
        return .flat
    }

    private static func deltaText(_ t: Double, _ y: Double?, unit: String) -> String? {
        guard let y else { return nil }
        let d = Int((t - y).rounded())
        if d == 0 { return "±0 \(unit)" }
        return "\(d > 0 ? "+" : "−")\(abs(d)) \(unit)"
    }

    private static func sleepDelta(_ t: Double, _ y: Double?) -> String? {
        guard let y else { return nil }
        let dm = Int(((t - y) / 60).rounded())
        if dm == 0 { return "±0m" }
        let h = abs(dm) / 60, m = abs(dm) % 60
        let mag = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return "\(dm > 0 ? "+" : "−")\(mag)"
    }

    private static func headline(for score: Int?, metrics: [RecoveryMetric]) -> String {
        guard let s = score else { return "Not enough data yet" }
        switch s {
        case 80...: return "Well recovered"
        case 60..<80: return "Solid recovery"
        case 40..<60: return "Moderately recovered"
        default: return "Take it easy today"
        }
    }
}
