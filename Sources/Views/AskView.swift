import SwiftUI

/// Ask freeform questions about today's readiness ("am I ready for a marathon?").
/// Answered by the built-in engine by default; by Gemma once downloaded.
struct AskView: View {
    let report: RecoveryReport
    @EnvironmentObject var gemma: GemmaModelManager
    @Environment(\.dismiss) private var dismiss

    @State private var question = ""
    @State private var answer: String?
    @State private var thinking = false
    @State private var showGemmaSheet = false

    private let suggestions = [
        "Am I ready for a marathon today?",
        "Should I do a hard workout?",
        "Is today a good day to rest?",
        "Can I push for a PR?",
    ]

    private var engine: LLMEngine { BuiltInEngine() }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        engineRow

                        if let answer {
                            answerCard(answer)
                        } else {
                            Text("Ask anything about how ready you are today. I'll weigh it against this morning's recovery.")
                                .font(.subheadline)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        suggestionChips

                        disclaimer
                    }
                    .padding(20)
                    .padding(.bottom, 90)
                }
                .scrollIndicators(.hidden)

                VStack { Spacer(); inputBar }
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
            .padding(14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.control))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    private func answerCard(_ text: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text(question).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textSecondary)
                Divider().overlay(Theme.cardStroke)
                Text(text).font(.callout).foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var suggestionChips: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TRY ASKING").font(.caption.weight(.semibold)).foregroundStyle(Theme.textSecondary).tracking(1.2)
            ForEach(suggestions, id: \.self) { s in
                Button { question = s; Task { await ask() } } label: {
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
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField("Ask about today…", text: $question)
                .textFieldStyle(.plain)
                .padding(.vertical, 12).padding(.horizontal, 16)
                .background(Capsule().fill(Theme.surface))
                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
                .submitLabel(.send)
                .onSubmit { Task { await ask() } }
            Button { Task { await ask() } } label: {
                Image(systemName: thinking ? "ellipsis" : "arrow.up")
                    .font(.headline.weight(.bold)).foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accent))
            }
            .disabled(question.trimmingCharacters(in: .whitespaces).isEmpty || thinking)
        }
        .padding(16)
        .background(LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle").font(.caption)
            Text("Answered entirely on your device. This is an AI estimate, not medical advice — it can be wrong. Complaints go to the model. 🙂")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textSecondary)
    }

    private func ask() async {
        let q = question.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        thinking = true
        answer = await engine.answer(question: q, context: report)
        thinking = false
    }
}
