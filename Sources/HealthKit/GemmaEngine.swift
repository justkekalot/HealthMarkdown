import Foundation
import MediaPipeTasksGenAI

/// Real on-device Gemma inference via MediaPipe LLM Inference (LlmInference).
/// Loads a .task model from disk and answers freeform questions, grounded in the
/// user's recovery data. Device-only — the MediaPipe binaries have no simulator
/// slice, and the model needs the increased-memory-limit entitlement.
actor GemmaEngine: LLMEngine {
    nonisolated let displayName: String

    private let modelPath: String
    private var llm: LlmInference?

    init(modelPath: String, displayName: String) {
        self.modelPath = modelPath
        self.displayName = displayName
    }

    private func ensureLoaded() throws {
        guard llm == nil else { return }
        let options = LlmInference.Options(modelPath: modelPath)
        options.maxTokens = 1024
        options.maxTopk = 40
        llm = try LlmInference(options: options)
    }

    func answer(question: String, context: RecoveryReport) async -> String {
        do {
            try ensureLoaded()
            guard let llm else { return "The model isn't loaded." }
            let prompt = Self.buildPrompt(question: question, context: context)
            // generateResponse blocks; we're already off the main thread (actor).
            return try llm.generateResponse(inputText: prompt)
        } catch {
            return "Gemma couldn't answer this time (\(error.localizedDescription)). The built-in engine still works."
        }
    }

    /// Compose a grounded prompt: give Gemma the recovery facts + the question,
    /// and constrain it to a short, wellness-framed (non-medical) answer.
    static func buildPrompt(question: String, context: RecoveryReport) -> String {
        var facts = "Recovery score: \(context.score.map(String.init) ?? "unknown")/100 (\(context.headline)).\n"
        for m in context.metrics {
            let dir = m.trend == .better ? "up" : m.trend == .worse ? "down" : "flat"
            let y = m.yesterdayText.map { " (yesterday \($0), \(dir))" } ?? ""
            facts += "- \(m.title): \(m.todayText)\(y)\n"
        }
        return """
        You are a concise, friendly fitness-recovery assistant inside a health app. \
        Use ONLY the data below to answer. Keep it under 90 words. Be encouraging but honest. \
        This is wellness guidance, not medical advice — never diagnose.

        This morning's data:
        \(facts)
        User question: "\(question)"

        Answer:
        """
    }
}
