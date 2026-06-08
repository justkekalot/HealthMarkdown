import UIKit
import CoreHaptics

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

    // MARK: - CoreHaptics scrub feedback

    /// One long-lived engine, lazily started. Auto-shuts-down when idle and is
    /// restarted on demand before each play; restarts itself after a reset.
    private static let engine: CHHapticEngine? = {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else { return nil }
        let e = try? CHHapticEngine()
        e?.isAutoShutdownEnabled = true
        e?.resetHandler = { try? e?.start() }
        try? e?.start()
        return e
    }()

    /// A crisp, snappy transient — for scrubbing. `intensity` (0…1) lets the
    /// caller scale the punch with the value under the finger, which feels far
    /// better than a flat picker tick. Falls back to a rigid impact when
    /// CoreHaptics isn't available.
    static func scrub(intensity: Float = 0.85) {
        let clamped = max(0.25, min(1, intensity))
        guard let engine else {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(clamped))
            return
        }
        let params = [
            CHHapticEventParameter(parameterID: .hapticIntensity, value: clamped),
            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.95),
        ]
        let event = CHHapticEvent(eventType: .hapticTransient, parameters: params, relativeTime: 0)
        do {
            try engine.start()
            let player = try engine.makePlayer(with: CHHapticPattern(events: [event], parameters: []))
            try player.start(atTime: 0)
        } catch {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: CGFloat(clamped))
        }
    }
}
