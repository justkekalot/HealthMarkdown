import Foundation

/// Produces the natural-language morning narrative from a RecoveryReport.
///
/// Two implementations:
///  - `TemplateNarrator` — deterministic, on-device, zero-dependency. Ships today.
///  - (planned) `GemmaNarrator` — Gemma 3n E4B via MediaPipe LLM Inference,
///    fully on-device. Drops in behind this same protocol once the model file
///    is bundled/downloaded. See note below.
///
/// Gemma note: Gemma 3n E4B is ~4.4GB (int4). That's too large to bundle in the
/// app binary, so it would ship as a first-run download with progress + a
/// Wi-Fi/size warning, cached in Application Support. Until that UX + the
/// MediaPipe dependency are in, the template narrator gives a real, useful
/// report so the feature is shippable now.
protocol RecoveryNarrator {
    func narrate(_ report: RecoveryReport) async -> String
}

/// Deterministic narrator — composes a friendly paragraph from the metrics.
struct TemplateNarrator: RecoveryNarrator {
    func narrate(_ report: RecoveryReport) async -> String {
        guard report.hasData else {
            return "I don't have enough overnight data yet. Wear your watch to sleep for a night or two and I'll start comparing your recovery morning over morning."
        }

        var lines: [String] = []
        if let s = report.score {
            lines.append("**\(report.headline)** — recovery \(s)/100.")
        } else {
            lines.append("**\(report.headline)**")
        }

        for m in report.metrics {
            let dir: String
            switch m.trend {
            case .better: dir = "up"
            case .worse: dir = "down"
            case .flat: dir = "steady"
            case .unknown: dir = "—"
            }
            if let d = m.deltaText, let y = m.yesterdayText, m.trend != .unknown {
                lines.append("\(m.title): \(m.todayText) (\(d) vs \(y), \(dir)).")
            } else {
                lines.append("\(m.title): \(m.todayText).")
            }
        }

        // A light, non-prescriptive nudge based on the score.
        if let s = report.score {
            switch s {
            case 80...: lines.append("You look ready — a good day to push if you want to.")
            case 60..<80: lines.append("A balanced day looks right — train as planned, listen to your body.")
            case 40..<60: lines.append("Maybe keep intensity moderate and prioritise sleep tonight.")
            default: lines.append("Your body's asking for recovery — favour rest, hydration, and an early night.")
            }
        }

        return lines.joined(separator: "\n\n")
    }
}
