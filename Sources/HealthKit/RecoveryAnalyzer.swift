import Foundation
import HealthKit

/// Computes a morning recovery snapshot from LAST NIGHT's sleep.
///
/// Deterministic, on-device math (no model) — the LLM narrates on top of it.
///
/// Two design principles, both driven by user feedback:
///  1. **Anchored to last night, stable all day.** Everything is measured over
///     the actual completed sleep window (bedtime→wake), not a rolling window
///     ending "now". Opening the app at 8am or 8pm gives the same score.
///  2. **Scored against your personal baseline, not yesterday.** Each signal is
///     turned into a z-score versus your own 60-day mean ± SD, then a logistic
///     curve maps that to 0–100. This is what HRV-guided training (Oura,
///     HRV4Training, Elite HRV) actually does — one noisy night doesn't swing
///     the score, and "normal for you" is what matters, not absolute numbers.
///
/// Composite weights: HRV 40% (the dominant autonomic-recovery signal), resting
/// HR 25%, sleep 25%, respiratory rate 10% (an illness/strain flag). Weights
/// renormalize over whatever signals are actually present.
enum RecoveryAnalyzer {

    // MARK: - Raw HealthKit reads

    /// Average of a discrete quantity over an interval (e.g. overnight HRV).
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

    /// The most recent sample of a quantity within `since…now` (value + date).
    private static func latestSample(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit, since: Date, now: Date) async -> (value: Double, date: Date)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    cont.resume(returning: (s.quantity.doubleValue(for: unit), s.endDate))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(q)
        }
    }

    /// Personal baseline: mean ± SD of the daily averages over the last `days`.
    /// nil until there's enough history (≥7 days) to be meaningful.
    private static func dailyBaseline(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, unit: HKUnit, days: Int, now: Date, calendar: Calendar) async -> (mean: Double, sd: Double)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let anchor = calendar.startOfDay(for: now)
        guard let start = calendar.date(byAdding: .day, value: -days, to: anchor) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: now, options: [])
        var comps = DateComponents(); comps.day = 1
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: .discreteAverage, anchorDate: anchor, intervalComponents: comps)
            q.initialResultsHandler = { _, results, _ in
                guard let results else { cont.resume(returning: nil); return }
                var vals: [Double] = []
                results.enumerateStatistics(from: start, to: now) { stat, _ in
                    if let a = stat.averageQuantity()?.doubleValue(for: unit) { vals.append(a) }
                }
                guard vals.count >= 7 else { cont.resume(returning: nil); return }
                let mean = vals.reduce(0, +) / Double(vals.count)
                let variance = vals.reduce(0) { $0 + ($1 - mean) * ($1 - mean) } / Double(vals.count - 1)
                cont.resume(returning: (mean, variance.squareRoot()))
            }
            store.execute(q)
        }
    }

    /// Last night's sleep as a fixed window + stage durations. Finds the most
    /// recent sleep session in the past 36h and returns [bedtime, wake]; this is
    /// stable once you're awake, so the score doesn't drift during the day.
    private static func lastNightSleep(_ store: HKHealthStore, now: Date, calendar: Calendar) async -> (interval: DateInterval, asleep: Double, rem: Double, core: Double, deep: Double)? {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return nil }
        let searchStart = calendar.date(byAdding: .hour, value: -36, to: now) ?? now
        let predicate = HKQuery.predicateForSamples(withStart: searchStart, end: now, options: [])
        let samples: [HKCategorySample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, s, _ in
                cont.resume(returning: (s as? [HKCategorySample]) ?? [])
            }
            store.execute(q)
        }
        let asleepValues: Set<Int> = [
            HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
            HKCategoryValueSleepAnalysis.asleepREM.rawValue,
            HKCategoryValueSleepAnalysis.asleepCore.rawValue,
            HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
        ]
        let asleepSamples = samples.filter { asleepValues.contains($0.value) }
        guard let latestEnd = asleepSamples.map(\.endDate).max() else { return nil }
        // The session = asleep samples within 18h before the latest wake.
        let windowStart = calendar.date(byAdding: .hour, value: -18, to: latestEnd) ?? latestEnd
        let night = asleepSamples.filter { $0.endDate > windowStart }
        guard let start = night.map(\.startDate).min(), let end = night.map(\.endDate).max() else { return nil }
        func dur(_ vals: Set<Int>) -> Double {
            night.filter { vals.contains($0.value) }.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        }
        return (DateInterval(start: start, end: end),
                dur(asleepValues),
                dur([HKCategoryValueSleepAnalysis.asleepREM.rawValue]),
                dur([HKCategoryValueSleepAnalysis.asleepCore.rawValue]),
                dur([HKCategoryValueSleepAnalysis.asleepDeep.rawValue]))
    }

    /// No sleep samples → a generic last-night window (prev ~23:00 → 08:00),
    /// anchored to the calendar so it's still fixed through the day.
    private static func fallbackNight(now: Date, calendar: Calendar) -> DateInterval {
        let eight = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: now) ?? now
        let end = min(eight, now)
        let start = calendar.date(byAdding: .hour, value: -9, to: end) ?? end
        return DateInterval(start: start, end: end)
    }

    // MARK: - Build

    /// Build the report. `now` is injectable for testing.
    static func build(store: HKHealthStore, now: Date = Date(), calendar: Calendar = .current) async -> RecoveryReport {
        let hrvUnit = HKUnit.secondUnit(with: .milli)
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let brpm = HKUnit.count().unitDivided(by: .minute())
        let vo2Unit = HKUnit(from: "ml/kg*min")

        // Anchor to last night's actual sleep (stable, completed window).
        let night = await lastNightSleep(store, now: now, calendar: calendar)
        let sleepInterval = night?.interval ?? fallbackNight(now: now, calendar: calendar)
        let recentStart = calendar.date(byAdding: .hour, value: -30, to: now) ?? now

        // Last-night physiology + 60-day personal baselines, in parallel.
        async let hrvNightA  = avg(store, .heartRateVariabilitySDNN, unit: hrvUnit, interval: sleepInterval)
        async let respNightA = avg(store, .respiratoryRate, unit: brpm, interval: sleepInterval)
        async let rhrLatestA = latestSample(store, .restingHeartRate, unit: bpm, since: recentStart, now: now)
        async let hrvBaseA   = dailyBaseline(store, .heartRateVariabilitySDNN, unit: hrvUnit, days: 60, now: now, calendar: calendar)
        async let rhrBaseA   = dailyBaseline(store, .restingHeartRate, unit: bpm, days: 60, now: now, calendar: calendar)
        async let respBaseA  = dailyBaseline(store, .respiratoryRate, unit: brpm, days: 60, now: now, calendar: calendar)

        // VO₂ Max — fitness context (not folded into the score). See below.
        let yearAgo = calendar.date(byAdding: .day, value: -365, to: now) ?? now
        let baseStart = calendar.date(byAdding: .day, value: -120, to: now) ?? now
        let baseEnd = calendar.date(byAdding: .day, value: -35, to: now) ?? now
        async let vo2LA = latestSample(store, .vo2Max, unit: vo2Unit, since: yearAgo, now: now)
        async let vo2BA = avg(store, .vo2Max, unit: vo2Unit, interval: DateInterval(start: baseStart, end: baseEnd))

        let hrvNight = await hrvNightA, respNight = await respNightA, rhrLatest = await rhrLatestA
        let hrvBase = await hrvBaseA, rhrBase = await rhrBaseA, respBase = await respBaseA
        let vo2Latest = await vo2LA, vo2Base = await vo2BA

        var metrics: [RecoveryMetric] = []
        var parts: [(score: Double, weight: Double)] = []

        // HRV (SDNN) — higher is better; the dominant recovery signal.
        if let v = hrvNight {
            if let b = hrvBase { parts.append((zScore01(v, b, higherBetter: true), 0.40)) }
            metrics.append(.init(key: "hrv", title: "HRV (SDNN)", symbol: "waveform.path.ecg",
                                 todayText: "\(Int(v.rounded())) ms", yesterdayText: nil,
                                 subtitle: hrvBase.map { "baseline \(Int($0.mean.rounded())) ms" } ?? "building baseline",
                                 deltaText: hrvBase.map { devText(v - $0.mean, unit: "ms") },
                                 trend: trendVsBaseline(v, hrvBase, higherBetter: true)))
        }

        // Resting heart rate — lower is better.
        if let v = rhrLatest?.value {
            if let b = rhrBase { parts.append((zScore01(v, b, higherBetter: false), 0.25)) }
            metrics.append(.init(key: "rhr", title: "Resting heart rate", symbol: "heart.fill",
                                 todayText: "\(Int(v.rounded())) bpm", yesterdayText: nil,
                                 subtitle: rhrBase.map { "baseline \(Int($0.mean.rounded())) bpm" } ?? "building baseline",
                                 deltaText: rhrBase.map { devText(v - $0.mean, unit: "bpm") },
                                 trend: trendVsBaseline(v, rhrBase, higherBetter: false)))
        }

        // Sleep — duration vs ~8h need, plus a deep+REM quality factor.
        if let n = night, n.asleep > 0 {
            parts.append((sleepScore(asleep: n.asleep, rem: n.rem, deep: n.deep), 0.25))
            let quality = n.rem + n.deep
            metrics.append(.init(key: "sleep", title: "Time asleep", symbol: "bed.double.fill",
                                 todayText: Fmt.duration(n.asleep), yesterdayText: nil,
                                 subtitle: quality > 0 ? "deep + REM \(Fmt.duration(quality))" : "of ~8h target",
                                 deltaText: sleepVsTarget(n.asleep),
                                 trend: sleepTrend(n.asleep)))
        }

        // Respiratory rate — lower/stable is better (elevation flags strain/illness).
        if let v = respNight, let b = respBase {
            parts.append((zScore01(v, b, higherBetter: false), 0.10))
            metrics.append(.init(key: "resp", title: "Respiratory rate", symbol: "lungs.fill",
                                 todayText: String(format: "%.1f br/min", v), yesterdayText: nil,
                                 subtitle: String(format: "baseline %.1f br/min", b.mean),
                                 deltaText: devTextF(v - b.mean, unit: "br/min"),
                                 trend: trendVsBaseline(v, b, higherBetter: false)))
        }

        // VO₂ Max — fitness context, latest reading + slow trend. NOT in the score.
        if let v = vo2Latest {
            metrics.append(.init(key: "vo2max", title: "VO₂ Max", symbol: "figure.run",
                                 todayText: "\(Fmt.plain(v.value, precision: 1)) ml/kg·min", yesterdayText: nil,
                                 subtitle: "latest · \(Fmt.shortDate(v.date))",
                                 deltaText: vo2Delta(v.value, vo2Base),
                                 trend: trendHigherBetter(v.value, vo2Base, tolerance: 0.5)))
        }

        let totalW = parts.reduce(0) { $0 + $1.weight }
        let score: Int? = totalW > 0 ? Int((parts.reduce(0) { $0 + $1.score * $1.weight } / totalW).rounded()) : nil
        return RecoveryReport(date: now, score: score, headline: headline(for: score), metrics: metrics)
    }

    // MARK: - Scoring

    /// Logistic map of a personal z-score to 0–100. z=0 (right on baseline) → 50;
    /// the 1.1 gain means ±1 SD lands near 75/25, ±2 SD near 90/10 — smooth, no
    /// hard clamp cliffs. `higherBetter` flips the sign for lower-is-better metrics.
    private static func zScore01(_ value: Double, _ baseline: (mean: Double, sd: Double), higherBetter: Bool) -> Double {
        guard baseline.sd > 0.0001 else { return 50 }
        var z = (value - baseline.mean) / baseline.sd
        if !higherBetter { z = -z }
        return 100 / (1 + exp(-1.1 * z))
    }

    private static func sleepScore(asleep: Double, rem: Double, deep: Double) -> Double {
        let need = 8.0 * 3600
        let durScore = min(1, asleep / need) * 100
        // Restorative sleep ≈ 40–50% deep+REM. Treat it as a gentle modifier
        // (floored at 60) rather than a hammer — stage data is noisy.
        guard asleep > 0, (rem + deep) > 0 else { return durScore }
        let q = (rem + deep) / asleep
        let qScore = max(60, min(100, q / 0.45 * 100))
        return 0.75 * durScore + 0.25 * qScore
    }

    private static func headline(for score: Int?) -> String {
        guard let s = score else { return "Not enough data yet" }
        switch s {
        case 80...:   return "Well recovered"
        case 60..<80: return "Solid recovery"
        case 40..<60: return "Moderately recovered"
        default:      return "Take it easy today"
        }
    }

    // MARK: - Trend / formatting helpers

    private static func trendVsBaseline(_ v: Double, _ baseline: (mean: Double, sd: Double)?, higherBetter: Bool) -> TrendDirection {
        guard let b = baseline, b.sd > 0.0001 else { return .unknown }
        let z = (v - b.mean) / b.sd
        let signed = higherBetter ? z : -z
        if signed > 0.4 { return .better }
        if signed < -0.4 { return .worse }
        return .flat
    }

    private static func devText(_ delta: Double, unit: String) -> String {
        let d = Int(delta.rounded())
        if d == 0 { return "on your baseline" }
        return "\(d > 0 ? "+" : "−")\(abs(d)) \(unit) vs normal"
    }

    private static func devTextF(_ delta: Double, unit: String) -> String {
        if abs(delta) < 0.05 { return "on your baseline" }
        return String(format: "%@%.1f %@ vs normal", delta > 0 ? "+" : "−", abs(delta), unit)
    }

    private static func sleepVsTarget(_ asleep: Double) -> String {
        let dm = Int(((asleep - 8 * 3600) / 60).rounded())
        if dm == 0 { return "on ~8h target" }
        let h = abs(dm) / 60, m = abs(dm) % 60
        let mag = h > 0 ? "\(h)h \(m)m" : "\(m)m"
        return "\(dm > 0 ? "+" : "−")\(mag) vs 8h"
    }

    private static func sleepTrend(_ asleep: Double) -> TrendDirection {
        let h = asleep / 3600
        if h >= 7.5 { return .better }
        if h < 6 { return .worse }
        return .flat
    }

    private static func trendHigherBetter(_ t: Double, _ y: Double?, tolerance: Double) -> TrendDirection {
        guard let y else { return .unknown }
        if t > y + tolerance { return .better }
        if t < y - tolerance { return .worse }
        return .flat
    }

    /// Slow VO₂ Max trend vs an earlier baseline. Dot decimal so it reads "+0.8".
    private static func vo2Delta(_ t: Double, _ base: Double?) -> String? {
        guard let base else { return nil }
        let d = t - base
        if abs(d) < 0.05 { return "±0.0 vs earlier" }
        return String(format: "%@%.1f vs earlier", d > 0 ? "+" : "−", abs(d))
    }
}
