import Foundation
import CoreLocation

/// Renders selected workouts to Markdown — always the *fullest* version, every
/// field HealthKit gave us. `human` is locale-formatted, fully bulleted (incl.
/// lap splits) for sharing; `digest` is the model-facing version (dot decimals,
/// one compact-but-complete line per workout) so Gemma reads the numbers right
/// without blowing its context on long split lists. Workouts are newest-first.
enum WorkoutMarkdown {

    // MARK: - Human-facing (fullest)

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
            var b: [String] = []
            func add(_ label: String, _ value: String?) { if let v = value { b.append("- **\(label):** \(v)") } }
            let n0: (Double) -> String = { Fmt.number($0, precision: 0) }
            let n1: (Double) -> String = { Fmt.number($0, precision: 1) }

            add("Duration", Fmt.duration(w.duration))
            add("Distance", w.distanceKm.flatMap { $0 > 0 ? "\(Fmt.number($0, precision: 2)) km" : nil })
            add("Pace", w.paceMinPerKm.map { "\(pace($0)) /km" })
            add("Avg speed", w.avgSpeedKmh.flatMap { $0 > 0 ? "\(n1($0)) km/h" : nil })
            add("Max speed", w.bestMaxSpeedKmh.flatMap { $0 > 0 ? "\(n1($0)) km/h" : nil })
            add("Active energy", w.energyKcal.flatMap { $0 > 0 ? "\(n0($0)) kcal" : nil })
            add("Total energy", w.totalEnergyKcal.flatMap { $0 > 0 ? "\(n0($0)) kcal" : nil })
            add("Heart rate", heartRate(w, n: { "\(Int($0.rounded()))" }))
            add("Avg MET", w.avgMET.map { "\(n1($0))" })
            add("Steps", w.stepCount.flatMap { $0 > 0 ? n0($0) : nil })
            add("Flights climbed", w.flightsClimbed.flatMap { $0 > 0 ? n0($0) : nil })
            add("Elevation gain", w.bestElevationGainM.flatMap { $0 > 0 ? "\(n0($0)) m" : nil })
            add("Elevation loss", w.routeElevationLossM.flatMap { $0 > 0 ? "\(n0($0)) m" : nil })
            add("Swim strokes", w.swimStrokeCount.flatMap { $0 > 0 ? n0($0) : nil })
            add("Pool length", w.swimLapLengthM.flatMap { $0 > 0 ? "\(n0($0)) m" : nil })
            add("Weather", weather(w, n: n0))
            add("Environment", w.indoor.map { $0 ? "Indoor" : "Outdoor" })
            if !w.lapDurations.isEmpty {
                add("Laps (\(w.lapDurations.count))", w.lapDurations.map { Fmt.duration($0) }.joined(separator: ", "))
            }
            add("Segments", w.segmentCount > 0 ? "\(w.segmentCount)" : nil)
            add("Source", w.sourceName)
            s += b.joined(separator: "\n") + "\n\n"
        }
        return s
    }

    // MARK: - Model-facing digest (complete, compact)

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

        // Many workouts won't fit the on-device model's context per-session, so
        // aggregate by activity type (still answers "estimate my VO2 max" etc.).
        guard workouts.count <= 35 else {
            s += aggregateByType(workouts)
            s += "\nEvery number above is exact, straight from Apple Health."
            return s
        }

        for w in workouts {
            let p0: (Double) -> String = { Fmt.plain($0, precision: 0) }
            let p1: (Double) -> String = { Fmt.plain($0, precision: 1) }
            var f: [String] = []
            if let d = w.distanceKm, d > 0 { f.append("\(Fmt.plain(d, precision: 2)) km") }
            if let p = w.paceMinPerKm { f.append("pace \(pace(p)) /km") }
            if let sp = w.avgSpeedKmh, sp > 0 { f.append("\(p1(sp)) km/h avg") }
            if let mx = w.bestMaxSpeedKmh, mx > 0 { f.append("\(p1(mx)) km/h max") }
            if let e = w.energyKcal, e > 0 { f.append("\(p0(e)) kcal active") }
            if let t = w.totalEnergyKcal, t > 0 { f.append("\(p0(t)) kcal total") }
            if let hr = heartRate(w, n: { "\(Int($0.rounded()))" }) { f.append("HR \(hr)") }
            if let m = w.avgMET { f.append("\(p1(m)) MET") }
            if let st = w.stepCount, st > 0 { f.append("\(p0(st)) steps") }
            if let fl = w.flightsClimbed, fl > 0 { f.append("\(p0(fl)) flights") }
            if let el = w.bestElevationGainM, el > 0 { f.append("\(p0(el)) m ascent") }
            if let lo = w.routeElevationLossM, lo > 0 { f.append("\(p0(lo)) m descent") }
            if let sc = w.swimStrokeCount, sc > 0 { f.append("\(p0(sc)) strokes") }
            if let wx = weather(w, n: p0) { f.append(wx) }
            if let ind = w.indoor { f.append(ind ? "indoor" : "outdoor") }
            if !w.lapDurations.isEmpty { f.append("\(w.lapDurations.count) laps") }
            if let src = w.sourceName { f.append("via \(src)") }
            s += "- \(w.activityName), \(Fmt.dateTime(w.start)), \(Fmt.duration(w.duration))"
            if !f.isEmpty { s += ": " + f.joined(separator: ", ") }
            s += ".\n"
        }
        s += "\nEvery number above is exact, straight from Apple Health."
        return s
    }

    /// Per-activity-type rollup for the chat digest of a large selection.
    private static func aggregateByType(_ workouts: [WorkoutDetail]) -> String {
        var order: [String] = [], groups: [String: [WorkoutDetail]] = [:]
        for w in workouts {
            if groups[w.activityName] == nil { order.append(w.activityName) }
            groups[w.activityName, default: []].append(w)
        }
        var s = "By activity type:\n"
        for name in order.sorted(by: { groups[$0]!.count > groups[$1]!.count }) {
            let g = groups[name]!
            let dur = g.reduce(0) { $0 + $1.duration }
            let dist = g.compactMap(\.distanceKm).reduce(0, +)
            let kcal = g.compactMap(\.energyKcal).reduce(0, +)
            let hrs = g.compactMap(\.avgHeartRate)
            var f = ["\(g.count) session\(g.count == 1 ? "" : "s")", Fmt.duration(dur)]
            if dist > 0 { f.append("\(Fmt.plain(dist, precision: 1)) km") }
            if kcal > 0 { f.append("\(Fmt.plain(kcal, precision: 0)) kcal") }
            if dist > 0, dur > 0 { f.append("avg pace \(pace((dur / 60) / dist)) /km") }
            if !hrs.isEmpty { f.append("avg HR \(Int((hrs.reduce(0, +) / Double(hrs.count)).rounded()))") }
            if let mx = g.compactMap(\.maxHeartRate).max() { f.append("max HR \(Int(mx.rounded()))") }
            if let el = g.compactMap(\.bestElevationGainM).max(), el > 0 { f.append("up to \(Fmt.plain(el, precision: 0)) m ascent") }
            s += "- \(name): " + f.joined(separator: ", ") + ".\n"
        }
        return s
    }

    // MARK: - Raw GPS track (RAW export)

    /// Every GPS point of one workout as a table — the rawest data Apple stores.
    static func rawTrack(for w: WorkoutDetail, points: [CLLocation]) -> String {
        var s = "## \(w.activityName) — \(Fmt.dateTime(w.start)) · \(points.count) points\n\n"
        s += "| Time | Latitude | Longitude | Alt (m) | Speed (m/s) | H.acc (m) |\n"
        s += "|---|---|---|---|---|---|\n"
        for p in points {
            let lat = Fmt.plain(p.coordinate.latitude, precision: 6)
            let lon = Fmt.plain(p.coordinate.longitude, precision: 6)
            let alt = Fmt.plain(p.altitude, precision: 1)
            let spd = p.speed >= 0 ? Fmt.plain(p.speed, precision: 2) : "—"
            let acc = p.horizontalAccuracy >= 0 ? Fmt.plain(p.horizontalAccuracy, precision: 1) : "—"
            s += "| \(Fmt.isoTimestamp(p.timestamp)) | \(lat) | \(lon) | \(alt) | \(spd) | \(acc) |\n"
        }
        return s + "\n"
    }

    // MARK: - Helpers

    private static func heartRate(_ w: WorkoutDetail, n: (Double) -> String) -> String? {
        guard let avg = w.avgHeartRate else { return nil }
        var s = "\(n(avg)) bpm avg"
        if let mn = w.minHeartRate, let mx = w.maxHeartRate { s += " (\(n(mn))–\(n(mx)) bpm)" }
        else if let mx = w.maxHeartRate { s += " (\(n(mx)) bpm max)" }
        return s
    }

    private static func weather(_ w: WorkoutDetail, n: (Double) -> String) -> String? {
        var parts: [String] = []
        if let t = w.weatherTempC { parts.append("\(n(t))°C") }
        if let h = w.weatherHumidityPct { parts.append("\(n(h))% humidity") }
        return parts.isEmpty ? nil : parts.joined(separator: ", ")
    }

    /// Minutes-per-km as M:SS.
    private static func pace(_ minPerKm: Double) -> String {
        let totalSeconds = Int((minPerKm * 60).rounded())
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}
