import Foundation
import LiteRTLM

/// Real on-device Gemma inference via LiteRT-LM (Google's on-device runtime —
/// the same one AI Edge Gallery uses). Loads a .litertlm model and answers
/// freeform questions grounded in the recovery data.
///
/// Uses the CPU backend: LiteRT-LM mmaps weights there, keeping the memory
/// footprint far below a naive full load. Device-only.
actor GemmaEngine: LLMEngine {
    nonisolated let displayName: String

    private let modelPath: String
    private var engine: Engine?

    init(modelPath: String, displayName: String) {
        self.modelPath = modelPath
        self.displayName = displayName
    }

    private func ensureLoaded() async throws {
        guard engine == nil else { return }
        let config = try EngineConfig(
            modelPath: modelPath,
            backend: .cpu(),
            maxNumTokens: 1024,
            cacheDir: NSTemporaryDirectory()
        )
        let engine = Engine(engineConfig: config)
        try await engine.initialize()
        self.engine = engine
    }

    func answer(question: String, context: RecoveryReport) async -> String {
        do {
            try await ensureLoaded()
            guard let engine else { return "The model isn't loaded." }
            let conversation = try await engine.createConversation()
            let prompt = Self.buildPrompt(question: question, context: context)
            // Use the streaming API — the one-shot sendMessage returns null in
            // the LiteRT-LM preview; the official sample streams and accumulates.
            var text = ""
            for try await chunk in conversation.sendMessageStream(Message(prompt)) {
                for content in chunk.contents {
                    if case let .text(t) = content { text += t }
                }
            }
            text = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty ? "Gemma returned an empty answer — try rephrasing." : text
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
