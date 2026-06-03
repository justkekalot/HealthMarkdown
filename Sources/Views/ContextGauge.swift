import SwiftUI

/// A slim "how full is the model's context window" bar. Turns from accent →
/// amber → red as it fills, so the user can see when an export/chat is getting
/// close to the limit.
struct ContextGauge: View {
    let used: Int
    let total: Int

    private var fraction: Double { min(1, Double(used) / Double(max(1, total))) }

    private var color: Color {
        switch fraction {
        case ..<0.7: return Theme.accent
        case ..<0.9: return Color(lightHex: 0xC9871F, darkHex: 0xE0A53A) // amber
        default:     return Color(lightHex: 0xC1543A, darkHex: 0xE0694C) // red-ish
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                .font(.caption2).foregroundStyle(Theme.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Theme.hairline.opacity(0.10))
                    Capsule().fill(color)
                        .frame(width: max(3, geo.size.width * fraction))
                        .animation(.easeInOut(duration: 0.4), value: fraction)
                }
            }
            .frame(height: 5)
            Text("\(Int(fraction * 100))%")
                .font(.caption2.monospacedDigit().weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: 34, alignment: .trailing)
        }
    }
}
