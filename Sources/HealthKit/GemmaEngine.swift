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

    /// The model's total token window (prompt + generation). Gemma 4 supports
    /// 32K; 8192 gives lots of room for bigger exports while staying light on
    /// memory/latency. Exposed so the chat UI can show a context-fill gauge.
    static let maxTokens = 8192

    /// Rough token estimate for the UI gauge (~4 chars/token for English/Markdown).
    static func estimateTokens(_ text: String) -> Int { max(1, text.count / 4) }

    private func ensureLoaded() async throws {
        guard engine == nil else { return }
        // GPU (Metal) backend — what the official sample and benchmarks use, and
        // viable now that the memory entitlement is in place. The CPU path threw
        // "Failed to invoke the compiled model" on this device.
        let config = try EngineConfig(
            modelPath: modelPath,
            backend: .gpu,
            maxNumTokens: Self.maxTokens,
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

    private var contextSent = false

    /// Reuse one conversation across turns (chat memory). The context (recovery
    /// data / export) is folded into the FIRST user message — system messages
    /// are unreliable in the LiteRT-LM preview, which is why "Gemma doesn't see
    /// the file" happened. Later turns send just the question, so memory holds.
    private func ask(question: String, systemContext: String, onToken: @escaping @Sendable (String) -> Void) async -> String {
        do {
            try await ensureLoaded()
            guard let engine else { return "The model isn't loaded." }
            if conversation == nil {
                let config = ConversationConfig(
                    samplerConfig: try SamplerConfig(topK: 1, topP: 1.0, temperature: 0.0)
                )
                conversation = try await engine.createConversation(with: config)
                contextSent = false
            }
            guard let conversation else { return "The model isn't ready." }
            // First turn: prepend the context so the model actually sees the data.
            let messageText: String
            if !contextSent {
                messageText = systemContext + "\n\n" + question
                contextSent = true
            } else {
                messageText = question
            }
            var text = ""
            for try await chunk in conversation.sendMessageStream(Message(messageText)) {
                // Stop cleanly if the chat was dismissed mid-generation.
                if Task.isCancelled { break }
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
        You are a precise health-data analyst inside an app. The user's Apple Health \
        export (Markdown) is below. Answer using ONLY numbers that literally appear in \
        the data — never invent, round wildly, or guess figures; if a value isn't in the \
        data, say you don't have it. Quote numbers exactly as written. Point out real \
        trends and changes. Keep answers under 120 words, don't repeat the whole context \
        each time. Wellness insight, not medical advice — never diagnose. Remember earlier turns.

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
