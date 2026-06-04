import Foundation

/// A single workout with the full per-session detail the Workouts tab exports.
/// Every field HealthKit exposes for a workout that we can read — the export is
/// always the "fullest" version, no slimming.
struct WorkoutDetail: Identifiable, Equatable {
    let id: UUID
    let activityName: String
    let symbol: String              // SF Symbol for the activity type
    let start: Date
    let end: Date
    let duration: TimeInterval      // active duration (excludes pauses)

    // Distance & energy
    let distanceKm: Double?
    let energyKcal: Double?          // active energy
    let totalEnergyKcal: Double?     // active + basal

    // Heart rate (over the session)
    let avgHeartRate: Double?
    let minHeartRate: Double?
    let maxHeartRate: Double?

    // Movement
    let avgSpeedKmh: Double?
    let maxSpeedKmh: Double?
    let stepCount: Double?
    let flightsClimbed: Double?
    let elevationAscendedM: Double?

    // Swimming
    let swimStrokeCount: Double?
    let swimLapLengthM: Double?

    // Effort & environment (from workout metadata)
    let avgMET: Double?
    let weatherTempC: Double?
    let weatherHumidityPct: Double?
    let indoor: Bool?

    // Provenance & structure
    let sourceName: String?
    let lapDurations: [TimeInterval] // per-lap splits, if recorded
    let segmentCount: Int

    /// Average pace in minutes per km, for distance-based workouts only.
    var paceMinPerKm: Double? {
        guard let d = distanceKm, d > 0.05, duration > 0 else { return nil }
        return (duration / 60) / d
    }
}
