import SwiftUI

/// Centralised visual language: colors, gradients, and reusable modifiers.
enum Theme {
    // Core palette — a warm-to-cool health spectrum on near-black.
    static let bg = Color(red: 0.04, green: 0.04, blue: 0.06)
    static let card = Color.white.opacity(0.06)
    static let cardStroke = Color.white.opacity(0.10)
    static let textPrimary = Color.white
    static let textSecondary = Color.white.opacity(0.62)

    static let accent = Color(red: 1.0, green: 0.32, blue: 0.40)      // vital pink-red
    static let accent2 = Color(red: 0.42, green: 0.45, blue: 1.0)     // cool indigo
    static let mint = Color(red: 0.20, green: 0.92, blue: 0.70)

    static var heroGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accent2],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var subtleGradient: LinearGradient {
        LinearGradient(
            colors: [accent.opacity(0.18), accent2.opacity(0.10)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

/// Animated ambient background — soft drifting blobs behind everything.
struct AmbientBackground: View {
    @State private var animate = false

    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()

            Circle()
                .fill(Theme.accent.opacity(0.35))
                .frame(width: 360, height: 360)
                .blur(radius: 120)
                .offset(x: animate ? -120 : -80, y: animate ? -260 : -300)

            Circle()
                .fill(Theme.accent2.opacity(0.32))
                .frame(width: 320, height: 320)
                .blur(radius: 130)
                .offset(x: animate ? 140 : 110, y: animate ? 320 : 360)

            Circle()
                .fill(Theme.mint.opacity(0.16))
                .frame(width: 260, height: 260)
                .blur(radius: 120)
                .offset(x: animate ? -160 : -120, y: animate ? 260 : 220)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 9).repeatForever(autoreverses: true)) {
                animate = true
            }
        }
    }
}

/// Glass card container.
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Theme.card)
                    .background(
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .fill(.ultraThinMaterial)
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

/// Primary call-to-action button style.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.heroGradient)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(.white.opacity(0.18), lineWidth: 1)
            )
            .shadow(color: Theme.accent.opacity(0.4), radius: 18, x: 0, y: 10)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.6), value: configuration.isPressed)
    }
}
