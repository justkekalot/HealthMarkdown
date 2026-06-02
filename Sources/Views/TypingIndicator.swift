import SwiftUI

/// A polished "thinking" indicator — three accent dots doing a smooth travelling
/// bounce, in a glass bubble. Used while the model is generating its first token.
struct TypingIndicator: View {
    @State private var phase = 0.0

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 8, height: 8)
                    .offset(y: bounce(i))
                    .opacity(0.55 + 0.45 * wave(i))
            }
        }
        .padding(.vertical, 14)
        .padding(.horizontal, 18)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.12), radius: 8, x: 0, y: 3)
        .onAppear {
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) {
                phase = 2 * .pi
            }
        }
    }

    // A travelling sine wave so the dots ripple left-to-right.
    private func wave(_ i: Int) -> Double {
        (sin(phase - Double(i) * 0.9) + 1) / 2
    }
    private func bounce(_ i: Int) -> CGFloat {
        CGFloat(-5 * wave(i))
    }
}
