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
        // GPU (Metal) backend — what the official sample and benchmarks use, and
        // viable now that the memory entitlement is in place. The CPU path threw
        // "Failed to invoke the compiled model" on this device.
        // Gemma 4 supports a large context (32K); 1024 was far too small and
        // rejected longer prompts (export chat: 2327 > 1024). 4096 fits a
        // trimmed export plus a full answer while staying light on memory.
        let config = try EngineConfig(
            modelPath: modelPath,
            backend: .gpu,
            maxNumTokens: 4096,
            cacheDir: NSTemporaryDirectory()
        )
        let engine = Engine(engineConfig: config)
        try await engine.initialize()
        self.engine = engine
    }

    func answer(question: String, context: RecoveryReport) async -> String {
        await stream(prompt: Self.buildPrompt(question: question, context: context), onToken: { _ in })
    }

    func answerAboutDocument(question: String, document: String) async -> String {
        await stream(prompt: Self.buildDocumentPrompt(question: question, document: document), onToken: { _ in })
    }

    func answerStreaming(question: String, context: RecoveryReport, onToken: @escaping @Sendable (String) -> Void) async -> String {
        await stream(prompt: Self.buildPrompt(question: question, context: context), onToken: onToken)
    }

    func answerAboutDocumentStreaming(question: String, document: String, onToken: @escaping @Sendable (String) -> Void) async -> String {
        await stream(prompt: Self.buildDocumentPrompt(question: question, document: document), onToken: onToken)
    }

    /// Shared streaming core — emits each chunk live via onToken; the one-shot
    /// sendMessage returns null in the LiteRT-LM preview, so we always stream.
    private func stream(prompt: String, onToken: @escaping @Sendable (String) -> Void) async -> String {
        do {
            try await ensureLoaded()
            guard let engine else { return "The model isn't loaded." }
            let conversation = try await engine.createConversation()
            var text = ""
            for try await chunk in conversation.sendMessageStream(Message(prompt)) {
                for content in chunk.contents {
                    if case let .text(t) = content { text += t; onToken(t) }
                }
            }
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? "Gemma returned an empty answer — try rephrasing." : trimmed
        } catch {
            return "Gemma couldn't answer this time (\(error.localizedDescription)). The built-in engine still works."
        }
    }

    /// Prompt for questions about an exported document. The document is already
    /// truncated by the caller to fit the model's context window.
    static func buildDocumentPrompt(question: String, document: String) -> String {
        """
        You are a concise health-data analyst. Below is an export of the user's \
        Apple Health data in Markdown. Answer the question using ONLY this data. \
        Point out trends, notable values, and changes over time where relevant. \
        Keep it under 120 words. This is wellness insight, not medical advice — never diagnose.

        --- EXPORT START ---
        \(document)
        --- EXPORT END ---

        Question: "\(question)"

        Answer:
        """
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
