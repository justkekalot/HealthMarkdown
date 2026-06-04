import Foundation
import HealthKit
import Combine

/// Owns the HKHealthStore, authorization flow, and all data fetching.
@MainActor
final class HealthKitManager: ObservableObject {

    enum AuthState: Equatable {
        case unknown
        case unavailable
        case requesting
        case authorized
        case denied
    }

    enum Phase: Equatable {
        case idle
        case fetching(progress: Double, label: String)
        case done
        case failed(String)
    }

    @Published var authState: AuthState = .unknown
    @Published var phase: Phase = .idle
    @Published var lastReport: HealthReport?
    /// Markdown for `lastReport`, generated once off the main thread so the
    /// preview/share never regenerates a large document on the UI thread.
    @Published var lastMarkdown: String = ""

    let store = HKHealthStore()
    private let connectedKey = "hasConnectedHealth"

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    init() {
        guard isAvailable else {
            authState = .unavailable
            return
        }
        // Once the user has connected once, skip the onboarding gate on every
        // subsequent launch. HealthKit deliberately never reveals read-permission
        // status, so we persist our own "connected" flag rather than re-prompting.
        if UserDefaults.standard.bool(forKey: connectedKey) {
            authState = .authorized
        } else {
            authState = .unknown
        }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard isAvailable else {
            authState = .unavailable
            return
        }
        authState = .requesting
        let readTypes = HealthCatalog.allReadTypes()
        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            // HealthKit never reveals read permission per-type for privacy reasons;
            // we treat a completed prompt as "ready to try reading".
            UserDefaults.standard.set(true, forKey: connectedKey)
            authState = .authorized
        } catch {
            authState = .denied
        }
    }

    // MARK: - Report generation

    func generateReport(for range: DateRangeOption, mode: ExportMode, customInterval: DateInterval? = nil) async {
        guard isAvailable else {
            phase = .failed("Health data isn't available on this device.")
            return
        }
        let interval = range.interval(customInterval: customInterval)
        var report = HealthReport(generatedAt: Date(), range: range, mode: mode, interval: interval)

        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: .strictStartDate)
        // Full and Raw modes run an extra raw pass over every quantity and category.
        let extraRawWork = mode.includesRaw ? HealthCatalog.quantities.count + HealthCatalog.categories.count : 0
        let totalSteps = HealthCatalog.quantities.count + 4 + extraRawWork
        var step = 0

        func advance(_ label: String) {
            step += 1
            phase = .fetching(progress: Double(step) / Double(totalSteps), label: label)
        }

        phase = .fetching(progress: 0, label: "Reading your profile…")

        // Profile / characteristics
        report.profile = readProfile()
        advance("Profile")

        // Quantities
        for spec in HealthCatalog.quantities {
            advance(spec.title)
            if let summary = await fetchQuantitySummary(spec: spec, predicate: predicate, interval: interval) {
                report.quantities.append(summary)
            }
        }

        // Sleep
        advance("Sleep")
        report.sleep = await fetchSleep(predicate: predicate)

        // Mindfulness
        advance("Mindfulness")
        report.mindful = await fetchMindful(predicate: predicate)

        // Workouts
        advance("Workouts")
        report.workouts = await fetchWorkouts(predicate: predicate)

        // Full & Raw exports: every raw sample for every metric that has data —
        // quantities AND category types (sleep, mindfulness), so weight, heart
        // rate, HRV and sleep all get a real time series, not just a summary.
        if mode.includesRaw {
            for spec in HealthCatalog.quantities {
                advance("\(spec.title) (raw)")
                if let series = await fetchRawSeries(spec: spec, interval: interval), series.hasData {
                    report.rawSeries.append(series)
                }
            }
            for spec in HealthCatalog.categories {
                advance("\(spec.title) (raw)")
                if let series = await fetchRawCategorySeries(spec: spec, interval: interval), series.hasData {
                    report.rawCategorySeries.append(series)
                }
            }
        }

        // Generate the (potentially very large) Markdown off the main thread.
        phase = .fetching(progress: 1, label: "Formatting Markdown…")
        let finalReport = report
        let markdown = await Task.detached(priority: .userInitiated) {
            MarkdownGenerator.generate(from: finalReport)
        }.value

        lastReport = report
        lastMarkdown = markdown
        phase = .done
    }

    // MARK: - Characteristics

    private func readProfile() -> ProfileSummary {
        var profile = ProfileSummary()
        if let dob = try? store.dateOfBirthComponents() {
            profile.dateOfBirth = dob
            if let year = dob.year,
               let birthDate = Calendar.current.date(from: dob) {
                let age = Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year
                profile.ageYears = age
                _ = year
            }
        }
        if let sex = try? store.biologicalSex() {
            profile.biologicalSex = Self.describe(sex: sex.biologicalSex)
        }
        if let blood = try? store.bloodType() {
            profile.bloodType = Self.describe(blood: blood.bloodType)
        }
        if let skin = try? store.fitzpatrickSkinType() {
            profile.skinType = Self.describe(skin: skin.skinType)
        }
        return profile
    }

    // MARK: - Quantity fetching

    private func fetchQuantitySummary(spec: QuantitySpec, predicate: NSPredicate, interval: DateInterval) async -> QuantitySummary? {
        guard let type = spec.quantityType else { return nil }

        let options: HKStatisticsOptions
        switch spec.aggregation {
        case .cumulativeSum:
            options = [.cumulativeSum]
        case .discreteAverage:
            options = [.discreteAverage, .discreteMin, .discreteMax]
        }

        let stats: HKStatistics? = await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: options) { _, result, _ in
                continuation.resume(returning: result)
            }
            store.execute(query)
        }

        let recent = await fetchMostRecent(type: type, unit: spec.unit)

        guard let stats else {
            // Even with no aggregate, surface the most-recent reading if present.
            if let recent {
                return QuantitySummary(spec: spec, total: nil, average: nil, dailyAverage: nil,
                                       min: nil, max: nil, mostRecent: recent.value,
                                       mostRecentDate: recent.date, sampleCount: 1)
            }
            return nil
        }

        let unit = spec.unit
        var total: Double?
        var average: Double?
        var minV: Double?
        var maxV: Double?

        switch spec.aggregation {
        case .cumulativeSum:
            total = stats.sumQuantity()?.doubleValue(for: unit)
        case .discreteAverage:
            average = stats.averageQuantity()?.doubleValue(for: unit)
            minV = stats.minimumQuantity()?.doubleValue(for: unit)
            maxV = stats.maximumQuantity()?.doubleValue(for: unit)
        }

        var dailyAverage: Double?
        if spec.aggregation == .cumulativeSum, let total {
            let days = max(1, Calendar.current.dateComponents([.day], from: interval.start, to: interval.end).day ?? 1)
            dailyAverage = total / Double(days)
        }

        // Percent units come back as fraction 0...1; scale for display.
        func scalePercent(_ v: Double?) -> Double? {
            guard let v else { return nil }
            return unit == HKUnit.percent() ? v * 100 : v
        }

        let hasAggregate = total != nil || average != nil
        let hasRecent = recent != nil
        guard hasAggregate || hasRecent else { return nil }

        return QuantitySummary(
            spec: spec,
            total: scalePercent(total),
            average: scalePercent(average),
            dailyAverage: scalePercent(dailyAverage),
            min: scalePercent(minV),
            max: scalePercent(maxV),
            mostRecent: scalePercent(recent?.value),
            mostRecentDate: recent?.date,
            sampleCount: hasAggregate ? max(1, recent != nil ? 2 : 1) : 1
        )
    }

    private func fetchMostRecent(type: HKQuantityType, unit: HKUnit) async -> (value: Double, date: Date)? {
        await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: type, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, _ in
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(returning: nil)
                    return
                }
                let scaled = unit == HKUnit.percent()
                    ? sample.quantity.doubleValue(for: unit) // keep raw; scaling handled by caller
                    : sample.quantity.doubleValue(for: unit)
                continuation.resume(returning: (scaled, sample.endDate))
            }
            store.execute(query)
        }
    }

    // MARK: - Raw samples (full export)

    /// Every individual sample for a metric — no bucketing, no averaging.
    /// This is the actual raw HealthKit export the user asked for.
    ///
    /// Uses an *overlap* predicate (not strictStartDate): discrete metrics like
    /// weight, heart rate and HRV are sparse, and a strict-start window can miss
    /// readings near the edges — which is why they previously showed only as a
    /// summary. For the all-time window we pass no predicate at all so nothing
    /// is excluded.
    private func fetchRawSeries(spec: QuantitySpec, interval: DateInterval) async -> QuantityRawSeries? {
        guard let type = spec.quantityType else { return nil }
        let unit = spec.unit
        let isPercent = unit == HKUnit.percent()
        // Always use the bounded overlap predicate. The all-time interval already
        // spans 2014→now (covers everything), and a nil predicate regressed to
        // returning zero samples — overlap is both correct and inclusive of
        // sparse discrete readings near the edges.
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])

        let samples: [HKQuantitySample] = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKQuantitySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let raw = samples.map { sample -> RawSample in
            var value = sample.quantity.doubleValue(for: unit)
            if isPercent { value *= 100 }
            return RawSample(
                start: sample.startDate,
                end: sample.endDate,
                value: value,
                source: sample.sourceRevision.source.name
            )
        }
        return QuantityRawSeries(spec: spec, samples: raw)
    }

    /// Raw category samples (sleep stages, mindful sessions) for the full export.
    private func fetchRawCategorySeries(spec: CategorySpec, interval: DateInterval) async -> CategoryRawSeries? {
        guard let type = spec.categoryType else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: interval.start, end: interval.end, options: [])

        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        guard !samples.isEmpty else { return nil }

        let unitLabel = spec.identifier == .sleepAnalysis ? "stage" : "session"
        let raw = samples.map { sample in
            RawCategorySample(
                start: sample.startDate,
                end: sample.endDate,
                label: Self.categoryLabel(for: spec.identifier, value: sample.value),
                source: sample.sourceRevision.source.name
            )
        }
        return CategoryRawSeries(title: spec.title, section: spec.section, unitLabel: unitLabel, samples: raw)
    }

    /// Human-readable label for a category sample value.
    static func categoryLabel(for id: HKCategoryTypeIdentifier, value: Int) -> String {
        if id == .sleepAnalysis {
            switch HKCategoryValueSleepAnalysis(rawValue: value) {
            case .inBed: return "In Bed"
            case .asleepUnspecified: return "Asleep"
            case .asleepREM: return "REM"
            case .asleepCore: return "Core"
            case .asleepDeep: return "Deep"
            case .awake: return "Awake"
            default: return "Asleep"
            }
        }
        return "Session"
    }

    // MARK: - Sleep

    private func fetchSleep(predicate: NSPredicate) async -> SleepSummary {
        guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return SleepSummary() }
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }

        var summary = SleepSummary()
        summary.sampleCount = samples.count
        var nightKeys = Set<String>()
        let cal = Calendar.current
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"

        for s in samples {
            let duration = s.endDate.timeIntervalSince(s.startDate)
            // Key nights by the date the sleep period started (rough but useful).
            nightKeys.insert(fmt.string(from: cal.startOfDay(for: s.startDate)))

            guard let value = HKCategoryValueSleepAnalysis(rawValue: s.value) else { continue }
            switch value {
            case .inBed:
                summary.inBed += duration
            case .asleepUnspecified:
                summary.totalAsleep += duration
            case .asleepREM:
                summary.rem += duration
                summary.totalAsleep += duration
            case .asleepCore:
                summary.core += duration
                summary.totalAsleep += duration
            case .asleepDeep:
                summary.deep += duration
                summary.totalAsleep += duration
            case .awake:
                summary.awake += duration
            @unknown default:
                break
            }
        }
        summary.nights = nightKeys.count
        return summary
    }

    // MARK: - Mindfulness

    private func fetchMindful(predicate: NSPredicate) async -> MindfulSummary {
        guard let type = HKCategoryType.categoryType(forIdentifier: .mindfulSession) else { return MindfulSummary() }
        let samples: [HKCategorySample] = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(sampleType: type, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKCategorySample]) ?? [])
            }
            store.execute(query)
        }
        var summary = MindfulSummary()
        summary.sessionCount = samples.count
        summary.totalDuration = samples.reduce(0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
        return summary
    }

    // MARK: - Workouts

    private func fetchWorkouts(predicate: NSPredicate) async -> WorkoutsSummary {
        let samples: [HKWorkout] = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }

        var summary = WorkoutsSummary()
        for w in samples {
            let energy = w.statistics(for: HKQuantityType(.activeEnergyBurned))?
                .sumQuantity()?.doubleValue(for: .kilocalorie())
            let distance = w.statistics(for: HKQuantityType(.distanceWalkingRunning))?
                .sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
                ?? w.statistics(for: HKQuantityType(.distanceCycling))?
                .sumQuantity()?.doubleValue(for: .meterUnit(with: .kilo))
            summary.workouts.append(
                WorkoutSummary(
                    activityName: Self.describe(activity: w.workoutActivityType),
                    start: w.startDate,
                    duration: w.duration,
                    energyKcal: energy,
                    distanceKm: distance
                )
            )
            summary.totalDuration += w.duration
            if let energy { summary.totalEnergy += energy }
            if let distance { summary.totalDistance += distance }
        }
        return summary
    }

    /// Individual workouts (newest first) over a window, with per-session HR —
    /// the data behind the Workouts tab's multi-select export.
    func fetchWorkoutList(since: Date, now: Date = Date()) async -> [WorkoutDetail] {
        let predicate = HKQuery.predicateForSamples(withStart: since, end: now, options: [])
        let samples: [HKWorkout] = await withCheckedContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
            let query = HKSampleQuery(sampleType: HKObjectType.workoutType(), predicate: predicate,
                                      limit: HKObjectQueryNoLimit, sortDescriptors: [sort]) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            store.execute(query)
        }
        let bpm = HKUnit.count().unitDivided(by: .minute())
        let mps = HKUnit.meter().unitDivided(by: .second())
        return samples.map { w in
            func sum(_ id: HKQuantityTypeIdentifier, _ unit: HKUnit) -> Double? {
                w.statistics(for: HKQuantityType(id))?.sumQuantity()?.doubleValue(for: unit)
            }
            func metaQty(_ key: String, _ unit: HKUnit) -> Double? {
                (w.metadata?[key] as? HKQuantity)?.doubleValue(for: unit)
            }

            let active = sum(.activeEnergyBurned, .kilocalorie())
            let basal = sum(.basalEnergyBurned, .kilocalorie())
            let total = (active != nil || basal != nil) ? (active ?? 0) + (basal ?? 0) : nil
            let distance = sum(.distanceWalkingRunning, .meterUnit(with: .kilo))
                ?? sum(.distanceCycling, .meterUnit(with: .kilo))
                ?? sum(.distanceSwimming, .meterUnit(with: .kilo))

            let hr = w.statistics(for: HKQuantityType(.heartRate))
            let speed = w.statistics(for: HKQuantityType(.runningSpeed))
                ?? w.statistics(for: HKQuantityType(.cyclingSpeed))
            // Fall back to average pace from distance/time when no speed series.
            let avgSpeed = (speed?.averageQuantity()?.doubleValue(for: mps)).map { $0 * 3.6 }
                ?? (w.duration > 0 ? distance.map { $0 / (w.duration / 3600) } : nil)
            let maxSpeed = (speed?.maximumQuantity()?.doubleValue(for: mps)).map { $0 * 3.6 }

            let laps = (w.workoutEvents ?? []).filter { $0.type == .lap }.map { $0.dateInterval.duration }
            let segments = (w.workoutEvents ?? []).filter { $0.type == .segment }.count

            return WorkoutDetail(
                id: w.uuid,
                activityName: Self.describe(activity: w.workoutActivityType),
                symbol: Self.symbol(activity: w.workoutActivityType),
                start: w.startDate, end: w.endDate, duration: w.duration,
                distanceKm: distance, energyKcal: active, totalEnergyKcal: total,
                avgHeartRate: hr?.averageQuantity()?.doubleValue(for: bpm),
                minHeartRate: hr?.minimumQuantity()?.doubleValue(for: bpm),
                maxHeartRate: hr?.maximumQuantity()?.doubleValue(for: bpm),
                avgSpeedKmh: avgSpeed, maxSpeedKmh: maxSpeed,
                stepCount: sum(.stepCount, .count()),
                flightsClimbed: sum(.flightsClimbed, .count()),
                elevationAscendedM: metaQty(HKMetadataKeyElevationAscended, .meter()),
                swimStrokeCount: sum(.swimmingStrokeCount, .count()),
                swimLapLengthM: metaQty(HKMetadataKeyLapLength, .meter()),
                avgMET: metaQty(HKMetadataKeyAverageMETs, HKUnit(from: "kcal/(kg*hr)")),
                weatherTempC: metaQty(HKMetadataKeyWeatherTemperature, .degreeCelsius()),
                weatherHumidityPct: metaQty(HKMetadataKeyWeatherHumidity, .percent()).map { $0 * 100 },
                indoor: (w.metadata?[HKMetadataKeyIndoorWorkout] as? NSNumber)?.boolValue,
                sourceName: w.sourceRevision.source.name,
                lapDurations: laps, segmentCount: segments)
        }
    }

    // MARK: - Describers

    static func describe(sex: HKBiologicalSex) -> String? {
        switch sex {
        case .female: return "Female"
        case .male: return "Male"
        case .other: return "Other"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    static func describe(blood: HKBloodType) -> String? {
        switch blood {
        case .aPositive: return "A+"
        case .aNegative: return "A−"
        case .bPositive: return "B+"
        case .bNegative: return "B−"
        case .abPositive: return "AB+"
        case .abNegative: return "AB−"
        case .oPositive: return "O+"
        case .oNegative: return "O−"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    static func describe(skin: HKFitzpatrickSkinType) -> String? {
        switch skin {
        case .I: return "Type I"
        case .II: return "Type II"
        case .III: return "Type III"
        case .IV: return "Type IV"
        case .V: return "Type V"
        case .VI: return "Type VI"
        case .notSet: return nil
        @unknown default: return nil
        }
    }

    static func describe(activity: HKWorkoutActivityType) -> String {
        switch activity {
        case .running: return "Running"
        case .walking: return "Walking"
        case .cycling: return "Cycling"
        case .swimming: return "Swimming"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "Strength Training"
        case .highIntensityIntervalTraining: return "HIIT"
        case .yoga: return "Yoga"
        case .hiking: return "Hiking"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .fencing: return "Fencing"
        case .coreTraining: return "Core Training"
        case .dance: return "Dance"
        case .pilates: return "Pilates"
        case .stairClimbing, .stairs: return "Stair Climbing"
        case .soccer: return "Soccer"
        case .basketball: return "Basketball"
        case .tennis: return "Tennis"
        case .climbing: return "Climbing"
        default: return "Workout"
        }
    }

    static func symbol(activity: HKWorkoutActivityType) -> String {
        switch activity {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .swimming: return "figure.pool.swim"
        case .traditionalStrengthTraining, .functionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "figure.highintensity.intervaltraining"
        case .yoga: return "figure.yoga"
        case .hiking: return "figure.hiking"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rower"
        case .fencing: return "figure.fencing"
        case .coreTraining: return "figure.core.training"
        case .dance: return "figure.dance"
        case .pilates: return "figure.pilates"
        case .stairClimbing, .stairs: return "figure.stair.stepper"
        case .soccer: return "figure.soccer"
        case .basketball: return "figure.basketball"
        case .tennis: return "figure.tennis"
        case .climbing: return "figure.climbing"
        default: return "figure.mixed.cardio"
        }
    }
}
