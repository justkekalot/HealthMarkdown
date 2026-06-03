import SwiftUI

/// A slim "how full is the model's memory" strip, sized to sit just above the
/// composer. It's quiet while there's room and only speaks up — a friendly
/// "almost full" plus an amber→red bar — as the chat approaches the limit.
struct ContextGauge: View {
    let used: Int
    let total: Int

    private var fraction: Double { min(1, Double(used) / Double(max(1, total))) }
    private var pct: Int { Int((fraction * 100).rounded()) }

    private var color: Color {
        switch fraction {
        case ..<0.7: return Theme.accent
        case ..<0.9: return Color(lightHex: 0xC9871F, darkHex: 0xE0A53A) // amber
        default:     return Color(lightHex: 0xC1543A, darkHex: 0xE0694C) // red-ish
        }
    }

    // Plain-language status — only turns into a caution when room runs low.
    private var label: String { fraction < 0.9 ? "Memory" : "Memory almost full" }

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(fraction < 0.9 ? Theme.textSecondary : color)
                .lineLimit(1)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline.opacity(0.10))
                    Capsule().fill(color)
                        .frame(width: max(3, geo.size.width * fraction))
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 4)
            Text("\(pct)%")
                .font(.caption2.monospacedDigit())
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 30, alignment: .trailing)
        }
    }
}
