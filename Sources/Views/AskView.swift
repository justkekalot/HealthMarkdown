import SwiftUI

/// Chat about today's readiness ("am I ready for a marathon?"). Answered by the
/// on-device Gemma model when downloaded, else the built-in engine.
struct AskView: View {
    let report: RecoveryReport
    @EnvironmentObject var gemma: GemmaModelManager
    @Environment(\.dismiss) private var dismiss

    struct ChatMessage: Identifiable, Equatable {
        let id = UUID()
        let role: Role
        var text: String
        enum Role { case user, assistant }
    }

    @State private var messages: [ChatMessage] = []
    @State private var question = ""
    @State private var thinking = false
    @State private var showGemmaSheet = false
    /// Held for the whole chat so the Gemma conversation (and its memory)
    /// persists across turns instead of resetting every message.
    @State private var sessionEngine: LLMEngine?

    private let suggestions = [
        "Am I ready for a marathon today?",
        "Should I do a hard workout?",
        "Is today a good day to rest?",
        "Can I push for a PR?",
    ]

    private func engineForSession() -> LLMEngine {
        if let e = sessionEngine { return e }
        let e = gemma.makeEngine() ?? BuiltInEngine()
        sessionEngine = e
        return e
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(spacing: 0) {
                    engineRow
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 8)

                    chatScroll

                    inputBar
                }
            }
            .navigationTitle("Ask")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
            .sheet(isPresented: $showGemmaSheet) { GemmaSetupView() }
        }
    }

    // MARK: - Chat list

    private var chatScroll: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                    }
                    ForEach(messages) { m in
                        bubble(m).id(m.id)
                    }
                    if thinking {
                        typingBubble.id("typing")
                    }
                    Color.clear.frame(height: 1).id("bottom")
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
            .onChange(of: messages) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
            .onChange(of: thinking) { _, _ in withAnimation { proxy.scrollTo("bottom", anchor: .bottom) } }
        }
    }

    private func bubble(_ m: ChatMessage) -> some View {
        HStack {
            if m.role == .user { Spacer(minLength: 40) }
            Text(m.text)
                .font(.callout)
                .foregroundStyle(m.role == .user ? Color.white : Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 11)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(m.role == .user ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.surface))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(m.role == .user ? Color.clear : Theme.cardStroke, lineWidth: 1)
                )
            if m.role == .assistant { Spacer(minLength: 40) }
        }
        .frame(maxWidth: .infinity, alignment: m.role == .user ? .trailing : .leading)
    }

    private var typingBubble: some View {
        TypingIndicator()
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Ask anything about how ready you are today — I'll weigh it against this morning's recovery.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

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

            disclaimer.padding(.top, 4)
        }
        .padding(.bottom, 8)
    }

    private var engineRow: some View {
        Button { showGemmaSheet = true } label: {
            HStack(spacing: 10) {
                Image(systemName: gemma.isReady ? "cpu.fill" : "cpu")
                    .foregroundStyle(Theme.accent)
                VStack(alignment: .leading, spacing: 1) {
                    Text(gemma.isReady ? gemma.selectedVariant.title : "Built-in engine")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(gemma.isReady ? "On-device model · tap to manage" : "Tap to download Gemma for richer answers")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.weight(.bold)).foregroundStyle(Theme.textSecondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.control))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about today…", text: $question)
                .textFieldStyle(.plain)
                .padding(.vertical, 12).padding(.horizontal, 16)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                .submitLabel(.send)
                .onSubmit { send(question) }
            Button { send(question) } label: {
                Image(systemName: "arrow.up")
                    .font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accent))
            }
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
            .opacity(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking ? 0.5 : 1)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").font(.caption)
            Text("Answered entirely on your device. This is an AI estimate, not medical advice — it can be wrong. Complaints go to the model. 🙂")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textSecondary)
    }

    // MARK: - Send

    private func send(_ text: String) {
        let q = text.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty, !thinking else { return }
        question = ""
        messages.append(ChatMessage(role: .user, text: q))
        thinking = true
        Haptics.tap()
        let eng = engineForSession()
        Task {
            // Keep the typing indicator until the FIRST token; only then create
            // the assistant bubble and stream into it (so there's never an empty
            // bubble sitting there looking broken).
            var assistantId: UUID?
            let full = await eng.answerStreaming(question: q, context: report) { chunk in
                Task { @MainActor in
                    if assistantId == nil {
                        thinking = false
                        Haptics.tick()
                        let m = ChatMessage(role: .assistant, text: chunk)
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
                    // No tokens streamed (error path) — show the returned text.
                    messages.append(ChatMessage(role: .assistant, text: full))
                }
                Haptics.success()
            }
        }
    }
}
