import Foundation

/// A single workout with the per-session detail the Workouts tab exports.
/// Richer than `WorkoutSummary` (which is just totals inside a health export):
/// this carries heart-rate stats and identity for multi-select.
struct WorkoutDetail: Identifiable, Equatable {
    let id: UUID
    let activityName: String
    let symbol: String              // SF Symbol for the activity type
    let start: Date
    let end: Date
    let duration: TimeInterval
    let distanceKm: Double?
    let energyKcal: Double?
    let avgHeartRate: Double?
    let maxHeartRate: Double?

    /// Average pace in minutes per km, for distance-based workouts only.
    var paceMinPerKm: Double? {
        guard let d = distanceKm, d > 0.05, duration > 0 else { return nil }
        return (duration / 60) / d
    }
}
