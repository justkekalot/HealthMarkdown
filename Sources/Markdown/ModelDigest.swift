import Foundation

/// A compact, AI-facing rendering of a HealthReport, built for the on-device
/// model — NOT for humans. The human Markdown is locale-formatted, table-heavy
/// and (for a Raw export) a wall of raw samples; a 4B model garbles numbers and
/// loses metrics in it. This digest fixes the three things that actually hurt
/// the model's accuracy:
///   • '.' decimals, no thousands grouping ("45.7", "12345") — so it can't read
///     a European "45,7" as 457.
///   • Plain "key: value" facts, one line per metric, never pipe tables.
///   • Always an aggregated summary (avg/min/max/latest, or total/daily), even
///     for a Raw export — every metric is present and compact, nothing is lost
///     to truncation.
enum ModelDigest {
    static func make(from report: HealthReport) -> String {
        var s = "Apple Health export, for you to analyse.\n"
        s += "Type: \(report.mode.title) — \(report.mode.subtitle).\n"
        s += "Window: \(Fmt.shortDate(report.interval.start)) to \(Fmt.shortDate(report.interval.end)) "
        s += "(\(report.range.title)).\n\n"

        // Quantity metrics, grouped by section in canonical order.
        let bySection = Dictionary(grouping: report.quantities.filter { $0.hasData }, by: { $0.spec.section })
        for section in HealthSection.allCases {
            let metrics = (bySection[section] ?? []).sorted { $0.spec.title < $1.spec.title }
            guard !metrics.isEmpty else { continue }
            s += "## \(section.title)\n"
            for m in metrics { s += "- \(line(m))\n" }
            s += "\n"
        }

        if report.sleep.hasData { s += sleepBlock(report.sleep) }
        if report.workouts.hasData { s += workoutsBlock(report.workouts) }
        if report.mindful.hasData {
            s += "## Mindfulness\n- \(report.mindful.sessionCount) sessions, "
            s += "\(Fmt.duration(report.mindful.totalDuration)) total.\n\n"
        }
        if report.profile.hasData { s += profileBlock(report.profile) }

        s += "Every number above is exact, straight from Apple Health. "
        s += "If a metric is not listed, it was not recorded in this window."
        return s
    }

    private static func line(_ m: QuantitySummary) -> String {
        let u = m.spec.unitLabel
        func n(_ v: Double?) -> String? { v.map { Fmt.plain($0, precision: m.spec.precision) } }
        switch m.spec.aggregation {
        case .cumulativeSum:
            var t = "\(m.spec.title): \(n(m.total) ?? "—") \(u) total"
            if let d = n(m.dailyAverage) { t += ", \(d) \(u)/day avg" }
            return t + " (\(m.sampleCount) samples)"
        case .discreteAverage:
            var t = "\(m.spec.title): \(n(m.average) ?? "—") \(u) avg"
            var extra: [String] = []
            if let mn = n(m.min) { extra.append("min \(mn)") }
            if let mx = n(m.max) { extra.append("max \(mx)") }
            if let r = n(m.mostRecent) {
                let date = m.mostRecentDate.map { " on \(Fmt.shortDate($0))" } ?? ""
                extra.append("latest \(r)\(date)")
            }
            if !extra.isEmpty { t += " (" + extra.joined(separator: ", ") + ")" }
            return t + " (\(m.sampleCount) samples)"
        }
    }

    private static func sleepBlock(_ s: SleepSummary) -> String {
        var t = "## Sleep\n"
        t += "- \(Fmt.duration(s.averageAsleepPerNight)) asleep per night avg over \(s.nights) nights "
        t += "(\(Fmt.duration(s.totalAsleep)) total).\n"
        var stages: [String] = []
        if s.rem > 0 { stages.append("REM \(Fmt.duration(s.rem))") }
        if s.core > 0 { stages.append("Core \(Fmt.duration(s.core))") }
        if s.deep > 0 { stages.append("Deep \(Fmt.duration(s.deep))") }
        if s.awake > 0 { stages.append("Awake \(Fmt.duration(s.awake))") }
        if !stages.isEmpty { t += "- Stage totals: " + stages.joined(separator: ", ") + ".\n" }
        return t + "\n"
    }

    private static func workoutsBlock(_ w: WorkoutsSummary) -> String {
        var t = "## Workouts\n- \(w.workouts.count) workouts, \(Fmt.duration(w.totalDuration)) total"
        if w.totalEnergy > 0 { t += ", \(Fmt.plain(w.totalEnergy, precision: 0)) kcal" }
        if w.totalDistance > 0 { t += ", \(Fmt.plain(w.totalDistance, precision: 1)) km" }
        return t + ".\n\n"
    }

    private static func profileBlock(_ p: ProfileSummary) -> String {
        var bits: [String] = []
        if let a = p.ageYears { bits.append("age \(a)") }
        if let sex = p.biologicalSex { bits.append(sex.lowercased()) }
        if let bt = p.bloodType { bits.append("blood type \(bt)") }
        guard !bits.isEmpty else { return "" }
        return "## Profile\n- " + bits.joined(separator: ", ") + ".\n\n"
    }
}
