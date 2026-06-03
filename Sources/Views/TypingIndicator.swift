import SwiftUI

/// A minimal "thinking" cue: three small dots rippling in a travelling wave.
/// Purely visual — driven by SwiftUI's own repeating animation, NOT a timer, and
/// it fires no haptics. (Haptics happen at discrete moments instead: a tap when
/// you send, a tick on the first token, a success chime when the answer lands.
/// An earlier timer-driven per-cycle buzz here never stopped while the chat was
/// open — that's gone.)
struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(animate ? 1.0 : 0.5)
                    .opacity(animate ? 1 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.6).repeatForever().delay(Double(i) * 0.18),
                        value: animate
                    )
            }
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1)
        )
        .onAppear { animate = true }
    }
}
