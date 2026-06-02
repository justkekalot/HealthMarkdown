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
    /// One persistent conversation per engine instance → the model keeps chat
    /// history. The view holds one engine for the whole chat session.
    private var conversation: Conversation?

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
        await ask(question: question, systemContext: Self.recoverySystem(context: context), onToken: { _ in })
    }

    func answerAboutDocument(question: String, document: String) async -> String {
        await ask(question: question, systemContext: Self.documentSystem(document: document), onToken: { _ in })
    }

    func answerStreaming(question: String, context: RecoveryReport, onToken: @escaping @Sendable (String) -> Void) async -> String {
        await ask(question: question, systemContext: Self.recoverySystem(context: context), onToken: onToken)
    }

    func answerAboutDocumentStreaming(question: String, document: String, onToken: @escaping @Sendable (String) -> Void) async -> String {
        await ask(question: question, systemContext: Self.documentSystem(document: document), onToken: onToken)
    }

    /// Reuse one conversation across turns (chat memory). The system context is
    /// set once when the conversation is created; each turn sends just the
    /// user's question. A non-zero temperature gives varied, non-robotic replies.
    private func ask(question: String, systemContext: String, onToken: @escaping @Sendable (String) -> Void) async -> String {
        do {
            try await ensureLoaded()
            guard let engine else { return "The model isn't loaded." }
            if conversation == nil {
                let config = ConversationConfig(
                    systemMessage: Message(systemContext, role: .system),
                    samplerConfig: try SamplerConfig(topK: 64, topP: 0.95, temperature: 1.0, seed: Int.random(in: 1...1_000_000))
                )
                conversation = try await engine.createConversation(with: config)
            }
            guard let conversation else { return "The model isn't ready." }
            var text = ""
            for try await chunk in conversation.sendMessageStream(Message(question)) {
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

    /// System context for the export chat — set once per conversation; the data
    /// is already truncated by the caller to fit the context window.
    static func documentSystem(document: String) -> String {
        """
        You are a concise health-data analyst inside an app. The user's Apple Health \
        export (Markdown) is below. Answer questions using ONLY this data — point out \
        trends, notable values, and changes over time. Keep answers under 120 words and \
        don't repeat the whole context each time. This is wellness insight, not medical \
        advice — never diagnose. Remember earlier turns in the conversation.

        --- EXPORT START ---
        \(document)
        --- EXPORT END ---
        """
    }

    /// System context for the readiness chat — set once per conversation.
    static func recoverySystem(context: RecoveryReport) -> String {
        var facts = "Recovery score: \(context.score.map(String.init) ?? "unknown")/100 (\(context.headline)).\n"
        for m in context.metrics {
            let dir = m.trend == .better ? "up" : m.trend == .worse ? "down" : "flat"
            let y = m.yesterdayText.map { " (yesterday \($0), \(dir))" } ?? ""
            facts += "- \(m.title): \(m.todayText)\(y)\n"
        }
        return """
        You are a concise, friendly fitness-recovery assistant inside a health app. \
        Use the user's data below to answer their questions. Keep answers under 90 words, \
        be encouraging but honest, and don't restate the full recovery numbers every time — \
        the user can see them. This is wellness guidance, not medical advice — never diagnose. \
        Remember earlier turns in this conversation.

        This morning's data:
        \(facts)
        """
    }
}
