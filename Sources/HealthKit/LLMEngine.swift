import Foundation

/// A question answered against the user's recovery context.
protocol LLMEngine {
    /// Human-readable name shown in the UI ("Built-in" vs "Gemma 3n").
    var displayName: String { get }
    func answer(question: String, context: RecoveryReport) async -> String
    /// Answer a question about an arbitrary exported document (e.g. "is there a
    /// trend?"). `document` is the export's Markdown (already truncated to fit).
    func answerAboutDocument(question: String, document: String) async -> String
}

extension LLMEngine {
    /// Default for engines that can't read free-form documents (the built-in
    /// rules engine). Gemma overrides this.
    func answerAboutDocument(question: String, document: String) async -> String {
        "Ask the on-device model (Gemma) about your exports — download it on the Readiness → Ask screen. The built-in engine only does recovery questions."
    }
}

/// On-device, zero-download engine. Deterministic rules over the recovery data —
/// good enough to answer "am I ready for X today?" honestly without a model.
/// This is the always-available default; Gemma (when downloaded) replaces it.
struct BuiltInEngine: LLMEngine {
    let displayName = "Built-in"

    func answer(question: String, context: RecoveryReport) async -> String {
        let q = question.lowercased()
        guard context.hasData, let score = context.score else {
            return "I don't have enough overnight data yet to judge that. Wear your watch to sleep for a night or two and ask again."
        }

        // Intensity-of-effort questions: marathon, race, hard workout, PR…
        let hardEffort = ["marathon", "race", "пробеж", "марафон", "hard", "intense", "pr ", "personal best", "long run", "тренировк", "workout", "lift", "heavy"]
        let isEffortQ = hardEffort.contains { q.contains($0) }

        let metricLine = context.metrics.map { m -> String in
            let arrow = m.trend == .better ? "↑" : m.trend == .worse ? "↓" : "→"
            return "\(m.title) \(m.todayText) \(arrow)"
        }.joined(separator: ", ")

        if isEffortQ {
            let verdict: String
            switch score {
            case 75...: verdict = "Yes — your body looks ready. Recovery is \(score)/100 and your overnight signals are solid. Fuel and hydrate well, warm up properly, and go for it."
            case 55..<75: verdict = "Probably, with care. Recovery is \(score)/100 — not peak, not depleted. You can take it on, but consider holding back the pace early and listen to your body."
            case 40..<55: verdict = "I'd be cautious. Recovery is only \(score)/100, so a max effort today carries more injury and burnout risk. If it's not a fixed race day, consider postponing or going easy."
            default: verdict = "I'd advise against a hard effort today. Recovery is \(score)/100 — your body is signalling it needs rest. Pushing now risks injury and a longer setback."
            }
            return "\(verdict)\n\nBased on this morning: \(metricLine)."
        }

        // Generic recovery question.
        return "\(context.headline) — recovery \(score)/100.\n\nThis morning: \(metricLine).\n\nAsk me about a specific effort (e.g. \"am I ready for a long run today?\") and I'll weigh it against these signals."
    }
}
