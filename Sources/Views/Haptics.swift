import UIKit

/// Lightweight haptic feedback helpers.
enum Haptics {
    /// A soft tap — e.g. when a generation starts.
    static func tap() {
        let g = UIImpactFeedbackGenerator(style: .light)
        g.prepare(); g.impactOccurred()
    }

    /// A very soft tick — e.g. per streamed token (used sparingly).
    static func tick() {
        let g = UIImpactFeedbackGenerator(style: .soft)
        g.impactOccurred(intensity: 0.4)
    }

    /// Success — e.g. when an answer finishes.
    static func success() {
        let g = UINotificationFeedbackGenerator()
        g.notificationOccurred(.success)
    }

    /// A crisp selection tick — for scrubbing across discrete values (the same
    /// feel as a picker wheel). Reuses one prepared generator for low latency.
    private static let selectionGenerator = UISelectionFeedbackGenerator()
    static func selection() {
        selectionGenerator.selectionChanged()
        selectionGenerator.prepare()   // keep the Taptic Engine warm for the next tick
    }
}
