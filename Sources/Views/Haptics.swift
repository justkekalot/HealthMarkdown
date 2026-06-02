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
}
