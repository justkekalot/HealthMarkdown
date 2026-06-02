import SwiftUI

/// Chat with the on-device model about a specific export ("is there a trend?").
struct ExportChatView: View {
    let title: String
    let markdown: String
    @EnvironmentObject var gemma: GemmaModelManager
    @Environment(\.dismiss) private var dismiss

    @State private var messages: [AskView.ChatMessage] = []
    @State private var question = ""
    @State private var thinking = false
    /// Held for the session so the Gemma conversation keeps its memory.
    @State private var sessionEngine: LLMEngine?

    /// Models have a bounded context window; a Full/Raw export can be MBs. Cap
    /// the document (~9k chars ≈ 2.5k tokens, leaving room for the prompt + a
    /// full answer inside the engine's 4096-token budget) and say when we cut.
    private static let maxChars = 9_000
    private var truncated: Bool { markdown.count > Self.maxChars }
    private var documentForModel: String {
        truncated ? String(markdown.prefix(Self.maxChars)) + "\n\n…(truncated)" : markdown
    }

    private let suggestions = [
        "Is there a trend in this data?",
        "What stands out?",
        "Summarise this for me.",
        "Anything I should watch?",
    ]

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(spacing: 0) {
                    header
                    chatScroll
                    inputBar
                }
            }
            .navigationTitle("Ask about export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: gemma.isReady ? "cpu.fill" : "cpu").foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary).lineLimit(1)
                Text(gemma.isReady ? "\(gemma.selectedVariant.title) · on-device" : "Built-in engine (limited)")
                    .font(.caption).foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.control))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
        .padding(.horizontal, 16).padding(.top, 12).padding(.bottom, 8)
    }

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty { emptyState }
                    ForEach(messages) { m in bubble(m).id(m.id) }
                    if thinking { typingBubble.id("typing") }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: thinking) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
    }

    private func bubble(_ m: AskView.ChatMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text)
                .font(.callout)
                .foregroundStyle(m.role == .user ? Color.white : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 11).padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(m.role == .user ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface)))
                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(m.role == .user ? Color.clear : Theme.cardStroke, lineWidth: 1))
            if m.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.role == .user ? .trailing : .leading)
    }

    private var typingBubble: some View {
        TypingIndicator().frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask the on-device model about this export — trends, what stands out, a summary.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
            if !gemma.isReady {
                Text("Download Gemma on the Readiness → Ask screen to chat about exports. The built-in engine can't read documents.")
                    .font(.footnote).foregroundStyle(Theme.accent).fixedSize(horizontal: false, vertical: true)
            }
            if truncated {
                Text("This export is large — the model sees the first part of it.")
                    .font(.caption2).foregroundStyle(Theme.textSecondary)
            }
            Text("TRY ASKING").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary).tracking(1.2)
            ForEach(suggestions, id: \.self) { s in
                Button { send(s) } label: {
                    HStack {
                        Text(s).font(.subheadline).foregroundStyle(Theme.textPrimary)
                        Spacer()
                        Image(systemName: "arrow.up.left").font(.caption).foregroundStyle(Theme.textSecondary)
                    }
                    .padding(.vertical, 11).padding(.horizontal, 14)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.control))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.bottom, 8)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about this export…", text: $question)
                .textFieldStyle(.plain)
                .padding(.vertical, 12).padding(.horizontal, 16)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                .submitLabel(.send)
                .onSubmit { send(question) }
            Button { send(question) } label: {
                Image(systemName: "arrow.up").font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46).background(Circle().fill(Theme.accent))
            }
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            .opacity(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking ? 0.5 : 1)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !thinking else { return }
        question = ""
        messages.append(.init(role: .user, text: q))
        thinking = true
        Haptics.tap()
        if sessionEngine == nil { sessionEngine = gemma.makeEngine() ?? BuiltInEngine() }
        let engine = sessionEngine!
        let doc = documentForModel
        Task {
            var assistantId: UUID?
            let full = await engine.answerAboutDocumentStreaming(question: q, document: doc) { chunk in
                Task { @MainActor in
                    if assistantId == nil {
                        thinking = false
                        Haptics.tick()
                        let m = AskView.ChatMessage(role: .assistant, text: chunk)
                        messages.append(m)
                        assistantId = m.id
                    } else if let id = assistantId, let idx = messages.firstIndex(where: { $0.id == id }) {
                        messages[idx].text += chunk
                    }
                }
            }
            await MainActor.run {
                thinking = false
                if let id = assistantId, let idx = messages.firstIndex(where: { $0.id == id }) {
                    messages[idx].text = full
                } else {
                    messages.append(AskView.ChatMessage(role: .assistant, text: full))
                }
                Haptics.success()
            }
        }
    }
}
