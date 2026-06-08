import Foundation
import HealthKit

/// Intraday stress proxy from heart rate relative to your resting baseline.
///
/// True all-day stress (Garmin / Whoop) is computed from beat-to-beat HRV,
/// which Apple Watch doesn't record continuously. As a pragmatic on-device
/// proxy we use heart-rate **elevation above your resting HR**, scaled by a
/// personal span and damped during movement so a walk or workout (exertion,
/// not stress) doesn't read as high stress. It's an estimate, not a clinical
/// measure.
///
/// Output: 24 hourly buckets ending at the current hour, plus a realtime "now"
/// value from the most recent heart-rate sample.
enum StressAnalyzer {
    private static let bpm = HKUnit.count().unitDivided(by: .minute())
    private static let stepUnit = HKUnit.count()

    /// Build the report. `now` is injectable for testing.
    static func build(store: HKHealthStore, now: Date = Date(), calendar: Calendar = .current) async -> StressReport {
        // Personal anchors for the HR → stress mapping.
        let twoWeeksAgo = calendar.date(byAdding: .day, value: -14, to: now) ?? now
        let restingHR = await latestSample(store, .restingHeartRate, since: twoWeeksAgo, now: now)?.value ?? 60
        let maxHR = estimatedMaxHR(store: store, now: now, calendar: calendar)
        // bpm above resting that maps to "fully stressed" (≈ 40% of HR reserve,
        // floored at 35) — sustained rest+span without movement ≈ 100.
        let span = max(35.0, 0.4 * (maxHR - restingHR))

        // 24 hourly buckets ending at the current clock hour.
        let thisHour = calendar.dateInterval(of: .hour, for: now)?.start ?? now
        let windowStart = calendar.date(byAdding: .hour, value: -23, to: thisHour) ?? thisHour
        async let hrByHourA   = hourly(store, .heartRate, options: .discreteAverage, start: windowStart, end: now, calendar: calendar) { $0.averageQuantity() }
        async let stepByHourA = hourly(store, .stepCount, options: .cumulativeSum, start: windowStart, end: now, calendar: calendar) { $0.sumQuantity() }
        let hrByHour = await hrByHourA
        let stepByHour = await stepByHourA

        var buckets: [StressBucket] = []
        var sum = 0, count = 0
        var hour = windowStart
        while hour <= now {
            if let hr = hrByHour[hour] {
                let s = stressValue(hr: hr, resting: restingHR, span: span, stepsPerHour: stepByHour[hour] ?? 0)
                buckets.append(.init(hour: hour, stress: s))
                sum += s; count += 1
            } else {
                buckets.append(.init(hour: hour, stress: nil))
            }
            guard let next = calendar.date(byAdding: .hour, value: 1, to: hour) else { break }
            hour = next
        }

        // Realtime "now" — latest HR in the last 15 min, damped by recent steps.
        let recent = calendar.date(byAdding: .minute, value: -15, to: now) ?? now
        let nowHR = await latestSample(store, .heartRate, since: recent, now: now)
        let stepWindow = calendar.date(byAdding: .minute, value: -20, to: now) ?? now
        let recentSteps = await sumValue(store, .stepCount, start: stepWindow, end: now) ?? 0
        // Scale ~20 min of steps to an hourly rate for the same damp curve.
        let nowStress = nowHR.map { stressValue(hr: $0.value, resting: restingHR, span: span, stepsPerHour: recentSteps * 3) }

        return StressReport(buckets: buckets,
                            now: nowStress,
                            nowAt: nowHR?.date,
                            restingHR: restingHR,
                            currentHR: nowHR?.value,
                            dayAverage: count > 0 ? Int((Double(sum) / Double(count)).rounded()) : nil,
                            updatedAt: now)
    }

    // MARK: - Stress math

    /// Map an hour's average HR to a 0–100 stress value. Elevation above resting
    /// drives it; sustained stepping damps it (the elevation is activity, not
    /// stress) — up to −70% at ~3000+ steps/hour.
    private static func stressValue(hr: Double, resting: Double, span: Double, stepsPerHour: Double) -> Int {
        let elevation = max(0, hr - resting)
        let base = min(1, elevation / span)
        let damp = 1 - 0.7 * min(1, max(0, (stepsPerHour - 300) / 3000))
        return Int((base * damp * 100).rounded())
    }

    /// Age-predicted max HR (220 − age) from the Health date of birth; a neutral
    /// 185 fallback when DOB isn't shared.
    private static func estimatedMaxHR(store: HKHealthStore, now: Date, calendar: Calendar) -> Double {
        if let dob = try? store.dateOfBirthComponents(), let year = dob.year {
            let age = max(10, min(100, calendar.component(.year, from: now) - year))
            return 220 - Double(age)
        }
        return 185
    }

    // MARK: - HealthKit reads

    /// Most recent sample (value + date) of a quantity within a window.
    private static func latestSample(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, since: Date, now: Date) async -> (value: Double, date: Date)? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: since, end: now, options: [])
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: type, predicate: predicate, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                if let s = samples?.first as? HKQuantitySample {
                    cont.resume(returning: (s.quantity.doubleValue(for: bpm), s.endDate))
                } else {
                    cont.resume(returning: nil)
                }
            }
            store.execute(q)
        }
    }

    /// Cumulative sum of a quantity over a window (e.g. steps in last 20 min).
    private static func sumValue(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, start: Date, end: Date) async -> Double? {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return await withCheckedContinuation { cont in
            let q = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, r, _ in
                cont.resume(returning: r?.sumQuantity()?.doubleValue(for: stepUnit))
            }
            store.execute(q)
        }
    }

    /// Hourly statistics over a window, keyed by clock-hour start. `pick` selects
    /// the average or sum quantity; the unit follows the identifier.
    private static func hourly(_ store: HKHealthStore, _ id: HKQuantityTypeIdentifier, options: HKStatisticsOptions, start: Date, end: Date, calendar: Calendar, pick: @escaping (HKStatistics) -> HKQuantity?) async -> [Date: Double] {
        guard let type = HKQuantityType.quantityType(forIdentifier: id) else { return [:] }
        let unit = (id == .stepCount) ? stepUnit : bpm
        let anchor = calendar.dateInterval(of: .hour, for: start)?.start ?? start
        var comps = DateComponents(); comps.hour = 1
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: [])
        return await withCheckedContinuation { cont in
            let q = HKStatisticsCollectionQuery(quantityType: type, quantitySamplePredicate: predicate,
                                                options: options, anchorDate: anchor, intervalComponents: comps)
            q.initialResultsHandler = { _, results, _ in
                var out: [Date: Double] = [:]
                results?.enumerateStatistics(from: start, to: end) { stat, _ in
                    if let v = pick(stat)?.doubleValue(for: unit) {
                        let key = calendar.dateInterval(of: .hour, for: stat.startDate)?.start ?? stat.startDate
                        out[key] = v
                    }
                }
                cont.resume(returning: out)
            }
            store.execute(q)
        }
    }
}
