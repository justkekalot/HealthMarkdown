import Foundation

/// Renders selected workouts to Markdown. Two outputs, same split as the health
/// export: `human` is locale-formatted and nicely sectioned for sharing; `digest`
/// is the model-facing version (dot decimals, plain facts) so Gemma reads the
/// numbers correctly. Workouts are assumed newest-first; both render in that order.
enum WorkoutMarkdown {

    // MARK: - Human-facing

    static func human(_ workouts: [WorkoutDetail]) -> String {
        guard let first = workouts.first, let last = workouts.last else { return "# Workouts\n\n_No workouts selected._\n" }
        var s = "# Workouts Export\n\n"
        let range = workouts.count == 1
            ? Fmt.shortDate(first.start)
            : "\(Fmt.shortDate(last.start)) – \(Fmt.shortDate(first.start))"
        s += "**\(workouts.count) workout\(workouts.count == 1 ? "" : "s")** · \(range)\n\n"

        let totalDur = workouts.reduce(0) { $0 + $1.duration }
        let totalDist = workouts.compactMap(\.distanceKm).reduce(0, +)
        let totalKcal = workouts.compactMap(\.energyKcal).reduce(0, +)
        var totals = ["\(Fmt.duration(totalDur))"]
        if totalDist > 0 { totals.append("\(Fmt.number(totalDist, precision: 1)) km") }
        if totalKcal > 0 { totals.append("\(Fmt.number(totalKcal, precision: 0)) kcal") }
        s += "**Totals:** " + totals.joined(separator: " · ") + "\n\n---\n\n"

        for w in workouts {
            s += "## \(w.activityName) — \(Fmt.dateTime(w.start))\n\n"
            s += "- **Duration:** \(Fmt.duration(w.duration))\n"
            if let d = w.distanceKm, d > 0 { s += "- **Distance:** \(Fmt.number(d, precision: 2)) km\n" }
            if let e = w.energyKcal, e > 0 { s += "- **Active energy:** \(Fmt.number(e, precision: 0)) kcal\n" }
            if let avg = w.avgHeartRate {
                let mx = w.maxHeartRate.map { ", \(Int($0.rounded())) bpm max" } ?? ""
                s += "- **Heart rate:** \(Int(avg.rounded())) bpm avg\(mx)\n"
            }
            if let p = w.paceMinPerKm { s += "- **Pace:** \(pace(p)) /km\n" }
            s += "\n"
        }
        return s
    }

    // MARK: - Model-facing digest

    static func digest(_ workouts: [WorkoutDetail]) -> String {
        var s = "Apple Health workouts export, for you to analyse.\n"
        let totalDur = workouts.reduce(0) { $0 + $1.duration }
        let totalDist = workouts.compactMap(\.distanceKm).reduce(0, +)
        let totalKcal = workouts.compactMap(\.energyKcal).reduce(0, +)
        if let first = workouts.first, let last = workouts.last {
            s += "\(workouts.count) workouts from \(Fmt.shortDate(last.start)) to \(Fmt.shortDate(first.start)). "
        }
        s += "Totals: \(Fmt.duration(totalDur))"
        if totalDist > 0 { s += ", \(Fmt.plain(totalDist, precision: 1)) km" }
        if totalKcal > 0 { s += ", \(Fmt.plain(totalKcal, precision: 0)) kcal" }
        s += ".\n\n"

        for w in workouts {
            var parts = "- \(w.activityName), \(Fmt.dateTime(w.start)): \(Fmt.duration(w.duration))"
            if let d = w.distanceKm, d > 0 { parts += ", \(Fmt.plain(d, precision: 2)) km" }
            if let e = w.energyKcal, e > 0 { parts += ", \(Fmt.plain(e, precision: 0)) kcal" }
            if let avg = w.avgHeartRate {
                let mx = w.maxHeartRate.map { " / \(Int($0.rounded())) max" } ?? ""
                parts += ", HR \(Int(avg.rounded())) avg\(mx) bpm"
            }
            if let p = w.paceMinPerKm { parts += ", pace \(pace(p)) /km" }
            s += parts + ".\n"
        }
        s += "\nEvery number above is exact, straight from Apple Health."
        return s
    }

    /// Minutes-per-km as M:SS.
    private static func pace(_ minPerKm: Double) -> String {
        let totalSeconds = Int((minPerKm * 60).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
