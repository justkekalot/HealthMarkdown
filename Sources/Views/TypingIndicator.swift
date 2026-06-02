import SwiftUI

/// A premium "thinking" moment: a softly breathing accent orb with an expanding
/// ripple ring and three orbiting sparks. Feels alive — interaction-design polish
/// for the seconds before the model's first token.
struct TypingIndicator: View {
    @State private var animate = false

    var body: some View {
        HStack(spacing: 12) {
            orb
            Text("Thinking")
                .font(.callout.weight(.medium))
                .foregroundStyle(Theme.textSecondary)
                .opacity(animate ? 1 : 0.5)
                .animation(.easeInOut(duration: 1.1).repeatForever(autoreverses: true), value: animate)
        }
        .padding(.vertical, 12)
        .padding(.leading, 12)
        .padding(.trailing, 18)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1)
        )
        .shadow(color: Theme.accent.opacity(0.14), radius: 12, x: 0, y: 4)
        .onAppear { animate = true }
    }

    private var orb: some View {
        ZStack {
            // Expanding ripple ring
            Circle()
                .stroke(Theme.accent.opacity(0.5), lineWidth: 2)
                .frame(width: 22, height: 22)
                .scaleEffect(animate ? 1.9 : 0.7)
                .opacity(animate ? 0 : 0.8)
                .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: animate)

            // Breathing core orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [Theme.accent, Theme.accentDeep],
                        center: .topLeading, startRadius: 1, endRadius: 18
                    )
                )
                .frame(width: 22, height: 22)
                .scaleEffect(animate ? 1.0 : 0.82)
                .shadow(color: Theme.accent.opacity(0.6), radius: animate ? 8 : 3)
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: animate)

            // Orbiting sparks
            ForEach(0..<3) { i in
                Circle()
                    .fill(Theme.accent)
                    .frame(width: 4, height: 4)
                    .offset(x: 15)
                    .rotationEffect(.degrees(animate ? 360 : 0))
                    .animation(
                        .linear(duration: 1.6).repeatForever(autoreverses: false)
                            .delay(Double(i) * 0.53),
                        value: animate
                    )
                    .opacity(0.7)
            }
        }
        .frame(width: 40, height: 40)
    }
}
