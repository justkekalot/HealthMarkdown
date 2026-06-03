import SwiftUI

/// A minimal "thinking" cue: three small dots rippling in a travelling wave,
/// with a soft haptic pulse once per cycle so you *feel* the model working.
/// Replaces the earlier breathing-orb design — the big dot read as too heavy.
struct TypingIndicator: View {
    @State private var phase = 0

    // Drives the wave and the haptic beat. One step every 0.42s → a full
    // three-dot cycle (and one soft tick) roughly once a second.
    private let beat = Timer.publish(every: 0.42, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(phase == i ? 1.4 : 0.85)
                    .opacity(phase == i ? 1 : 0.4)
                    .animation(.easeInOut(duration: 0.42), value: phase)
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
        .onReceive(beat) { _ in
            let next = (phase + 1) % 3
            phase = next
            // One gentle pulse per cycle (when the crest returns to the first dot).
            if next == 0 { Haptics.tick() }
        }
    }
}
