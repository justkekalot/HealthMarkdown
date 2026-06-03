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

        // Interpretation, not a re-list — the metric rows below already show the
        // numbers. Here we say what they *mean* together, then one nudge.
        var parts: [String] = []

        // What's driving the score: name the standout improvement and concern.
        // Only the overnight signals — VO₂ Max is a slow fitness metric, not a
        // day-over-day change, so it doesn't belong in "vs yesterday" wording.
        let daily = report.metrics.filter { $0.key != "vo2max" }
        let improved = daily.filter { $0.trend == .better }
        let worsened = daily.filter { $0.trend == .worse }
        if let win = improved.first, let loss = worsened.first {
            parts.append("Your \(win.title.lowercased()) improved, but \(loss.title.lowercased()) moved the wrong way — so your body is recovered, just not fully topped up.")
        } else if !improved.isEmpty {
            let names = improved.map { $0.title.lowercased() }.joined(separator: " and ")
            parts.append("Good signs across the board — \(names) all improved versus yesterday.")
        } else if !worsened.isEmpty {
            let names = worsened.map { $0.title.lowercased() }.joined(separator: " and ")
            parts.append("A few signals slipped — \(names) came in below yesterday, which usually means incomplete recovery.")
        } else {
            parts.append("Your overnight signals held steady versus yesterday.")
        }

        if let s = report.score {
            switch s {
            case 80...: parts.append("You look ready — a good day to push if you want to.")
            case 60..<80: parts.append("Train as planned, just listen to your body.")
            case 40..<60: parts.append("Keep intensity moderate today and prioritise sleep tonight.")
            default: parts.append("Favour rest, hydration, and an early night.")
            }
        }

        return parts.joined(separator: " ")
    }
}
