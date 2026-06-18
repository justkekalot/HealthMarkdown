import Foundation
import HealthKit

/// How a quantity metric should be aggregated over the selected window.
enum Aggregation {
    case cumulativeSum   // steps, energy, distance, water, nutrients...
    case discreteAverage // heart rate, body mass, SpO2, temperature...
}

/// A single quantity metric we know how to read and summarise.
struct QuantitySpec: Identifiable {
    let identifier: HKQuantityTypeIdentifier
    let title: String
    let unit: HKUnit
    let unitLabel: String
    let aggregation: Aggregation
    let section: HealthSection
    /// Number of decimal places to show.
    let precision: Int

    var id: String { identifier.rawValue }

    var quantityType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: identifier)
    }
}

/// A category metric (sleep, mindful sessions) read as samples.
struct CategorySpec: Identifiable {
    let identifier: HKCategoryTypeIdentifier
    let title: String
    let section: HealthSection

    var id: String { identifier.rawValue }

    var categoryType: HKCategoryType? {
        HKCategoryType.categoryType(forIdentifier: identifier)
    }
}

/// The full catalog of Health data this app reads. Adding a row here is the only
/// step required to surface a new metric in both the UI and the Markdown export.
enum HealthCatalog {

    static let quantities: [QuantitySpec] = [
        // MARK: Activity
        .init(identifier: .stepCount, title: "Steps", unit: .count(), unitLabel: "steps", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .distanceWalkingRunning, title: "Walking + Running Distance", unit: .meterUnit(with: .kilo), unitLabel: "km", aggregation: .cumulativeSum, section: .activity, precision: 1),
        .init(identifier: .distanceCycling, title: "Cycling Distance", unit: .meterUnit(with: .kilo), unitLabel: "km", aggregation: .cumulativeSum, section: .activity, precision: 1),
        .init(identifier: .distanceSwimming, title: "Swimming Distance", unit: .meterUnit(with: .kilo), unitLabel: "km", aggregation: .cumulativeSum, section: .activity, precision: 2),
        .init(identifier: .swimmingStrokeCount, title: "Swimming Strokes", unit: .count(), unitLabel: "strokes", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .flightsClimbed, title: "Flights Climbed", unit: .count(), unitLabel: "flights", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .activeEnergyBurned, title: "Active Energy", unit: .kilocalorie(), unitLabel: "kcal", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .basalEnergyBurned, title: "Resting Energy", unit: .kilocalorie(), unitLabel: "kcal", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .appleExerciseTime, title: "Exercise Time", unit: .minute(), unitLabel: "min", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .appleStandTime, title: "Stand Time", unit: .minute(), unitLabel: "min", aggregation: .cumulativeSum, section: .activity, precision: 0),
        .init(identifier: .pushCount, title: "Wheelchair Pushes", unit: .count(), unitLabel: "pushes", aggregation: .cumulativeSum, section: .activity, precision: 0),

        // MARK: Heart
        .init(identifier: .heartRate, title: "Heart Rate", unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "bpm", aggregation: .discreteAverage, section: .heart, precision: 0),
        .init(identifier: .restingHeartRate, title: "Resting Heart Rate", unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "bpm", aggregation: .discreteAverage, section: .heart, precision: 0),
        .init(identifier: .walkingHeartRateAverage, title: "Walking Heart Rate Avg", unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "bpm", aggregation: .discreteAverage, section: .heart, precision: 0),
        .init(identifier: .heartRateVariabilitySDNN, title: "Heart Rate Variability (SDNN)", unit: .secondUnit(with: .milli), unitLabel: "ms", aggregation: .discreteAverage, section: .heart, precision: 0),
        .init(identifier: .vo2Max, title: "VO₂ Max", unit: HKUnit(from: "ml/kg*min"), unitLabel: "ml/kg·min", aggregation: .discreteAverage, section: .heart, precision: 1),

        // MARK: Body
        .init(identifier: .bodyMass, title: "Body Mass", unit: .gramUnit(with: .kilo), unitLabel: "kg", aggregation: .discreteAverage, section: .body, precision: 1),
        .init(identifier: .height, title: "Height", unit: .meterUnit(with: .centi), unitLabel: "cm", aggregation: .discreteAverage, section: .body, precision: 0),
        .init(identifier: .bodyMassIndex, title: "Body Mass Index", unit: .count(), unitLabel: "BMI", aggregation: .discreteAverage, section: .body, precision: 1),
        .init(identifier: .bodyFatPercentage, title: "Body Fat", unit: .percent(), unitLabel: "%", aggregation: .discreteAverage, section: .body, precision: 1),
        .init(identifier: .leanBodyMass, title: "Lean Body Mass", unit: .gramUnit(with: .kilo), unitLabel: "kg", aggregation: .discreteAverage, section: .body, precision: 1),
        .init(identifier: .waistCircumference, title: "Waist Circumference", unit: .meterUnit(with: .centi), unitLabel: "cm", aggregation: .discreteAverage, section: .body, precision: 1),

        // MARK: Vitals
        .init(identifier: .bloodPressureSystolic, title: "Blood Pressure (Systolic)", unit: .millimeterOfMercury(), unitLabel: "mmHg", aggregation: .discreteAverage, section: .vitals, precision: 0),
        .init(identifier: .bloodPressureDiastolic, title: "Blood Pressure (Diastolic)", unit: .millimeterOfMercury(), unitLabel: "mmHg", aggregation: .discreteAverage, section: .vitals, precision: 0),
        .init(identifier: .bodyTemperature, title: "Body Temperature", unit: .degreeCelsius(), unitLabel: "°C", aggregation: .discreteAverage, section: .vitals, precision: 1),
        .init(identifier: .bloodGlucose, title: "Blood Glucose", unit: HKUnit(from: "mg/dL"), unitLabel: "mg/dL", aggregation: .discreteAverage, section: .vitals, precision: 0),

        // MARK: Respiratory
        .init(identifier: .respiratoryRate, title: "Respiratory Rate", unit: HKUnit.count().unitDivided(by: .minute()), unitLabel: "breaths/min", aggregation: .discreteAverage, section: .respiratory, precision: 0),
        .init(identifier: .oxygenSaturation, title: "Blood Oxygen", unit: .percent(), unitLabel: "%", aggregation: .discreteAverage, section: .respiratory, precision: 1),

        // MARK: Nutrition
        .init(identifier: .dietaryEnergyConsumed, title: "Dietary Energy", unit: .kilocalorie(), unitLabel: "kcal", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryProtein, title: "Protein", unit: .gram(), unitLabel: "g", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryCarbohydrates, title: "Carbohydrates", unit: .gram(), unitLabel: "g", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryFatTotal, title: "Total Fat", unit: .gram(), unitLabel: "g", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryFiber, title: "Fiber", unit: .gram(), unitLabel: "g", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietarySugar, title: "Sugar", unit: .gram(), unitLabel: "g", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryWater, title: "Water", unit: .literUnit(with: .milli), unitLabel: "mL", aggregation: .cumulativeSum, section: .nutrition, precision: 0),
        .init(identifier: .dietaryCaffeine, title: "Caffeine", unit: .gramUnit(with: .milli), unitLabel: "mg", aggregation: .cumulativeSum, section: .nutrition, precision: 0),

        // MARK: Mobility
        .init(identifier: .walkingSpeed, title: "Walking Speed", unit: HKUnit(from: "km/hr"), unitLabel: "km/h", aggregation: .discreteAverage, section: .mobility, precision: 1),
        .init(identifier: .walkingStepLength, title: "Walking Step Length", unit: .meterUnit(with: .centi), unitLabel: "cm", aggregation: .discreteAverage, section: .mobility, precision: 0),
        .init(identifier: .walkingDoubleSupportPercentage, title: "Double Support Time", unit: .percent(), unitLabel: "%", aggregation: .discreteAverage, section: .mobility, precision: 1),
        .init(identifier: .walkingAsymmetryPercentage, title: "Walking Asymmetry", unit: .percent(), unitLabel: "%", aggregation: .discreteAverage, section: .mobility, precision: 1),
        .init(identifier: .sixMinuteWalkTestDistance, title: "Six-Minute Walk Distance", unit: .meter(), unitLabel: "m", aggregation: .discreteAverage, section: .mobility, precision: 0),

        // MARK: Hearing
        .init(identifier: .environmentalAudioExposure, title: "Environmental Sound Levels", unit: .decibelAWeightedSoundPressureLevel(), unitLabel: "dBASPL", aggregation: .discreteAverage, section: .audio, precision: 0),
        .init(identifier: .headphoneAudioExposure, title: "Headphone Audio Levels", unit: .decibelAWeightedSoundPressureLevel(), unitLabel: "dBASPL", aggregation: .discreteAverage, section: .audio, precision: 0),
    ]

    static let categories: [CategorySpec] = [
        .init(identifier: .sleepAnalysis, title: "Sleep Analysis", section: .sleep),
        .init(identifier: .mindfulSession, title: "Mindful Sessions", section: .mindfulness),
    ]

    /// Pseudo-id for workouts in the custom-export selection (workouts aren't a
    /// quantity/category spec but are selectable just like one).
    static let workoutsID = "workouts"

    /// The read types for a set of selected metric ids — used to request access
    /// for exactly what the user picked in the custom export.
    static func readTypes(forIDs ids: Set<String>) -> Set<HKObjectType> {
        var out = Set<HKObjectType>()
        for q in quantities where ids.contains(q.id) { if let t = q.quantityType { out.insert(t) } }
        for c in categories where ids.contains(c.id) { if let t = c.categoryType { out.insert(t) } }
        if ids.contains(workoutsID) { out.insert(HKObjectType.workoutType()) }
        return out
    }

    /// Every read type, for the authorization request.
    static func allReadTypes() -> Set<HKObjectType> {
        var types = Set<HKObjectType>()
        for q in quantities { if let t = q.quantityType { types.insert(t) } }
        for c in categories { if let t = c.categoryType { types.insert(t) } }
        types.insert(HKObjectType.workoutType())
        // Workout routes are authorized separately (ensureRouteAccess) because
        // they require the workout type in the SHARE set — can't go in this
        // read-only set without throwing.
        // Characteristics
        if let dob = HKCharacteristicType.characteristicType(forIdentifier: .dateOfBirth) { types.insert(dob) }
        if let sex = HKCharacteristicType.characteristicType(forIdentifier: .biologicalSex) { types.insert(sex) }
        if let blood = HKCharacteristicType.characteristicType(forIdentifier: .bloodType) { types.insert(blood) }
        if let skin = HKCharacteristicType.characteristicType(forIdentifier: .fitzpatrickSkinType) { types.insert(skin) }
        return types
    }
}
