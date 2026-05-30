import SwiftUI
import UIKit

/// A color that resolves differently in light and dark mode.
extension Color {
    init(lightHex light: UInt32, darkHex dark: UInt32) {
        self = Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? UIColor(rgb: dark) : UIColor(rgb: light)
        })
    }
}

private extension UIColor {
    convenience init(rgb: UInt32) {
        self.init(
            red: CGFloat((rgb >> 16) & 0xFF) / 255,
            green: CGFloat((rgb >> 8) & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255,
            alpha: 1
        )
    }
}

/// Centralised visual language.
///
/// Design direction — "clinical editorial": this is a tool that turns your
/// health into a *document*, so the look is paper-and-ink, not neon. One warm
/// terracotta accent (a quiet nod to the heart / vitality), generous space,
/// hairline borders, depth from soft shadow rather than glow. Fully adaptive to
/// light and dark.
enum Theme {
    // Surfaces
    static let bg = Color(lightHex: 0xF4F1EA, darkHex: 0x141310)        // warm paper / warm near-black
    static let bgElevated = Color(lightHex: 0xFBFAF6, darkHex: 0x1C1A16)
    static let surface = Color(lightHex: 0xFFFFFF, darkHex: 0x201E19)   // cards
    static let surfaceSunken = Color(lightHex: 0xEFEBE2, darkHex: 0x100F0C)

    // Ink
    static let textPrimary = Color(lightHex: 0x1A1714, darkHex: 0xF2EDE4)
    static let textSecondary = Color(lightHex: 0x6E665B, darkHex: 0xA49C90)
    static let hairline = Color(lightHex: 0x000000, darkHex: 0xFFFFFF)  // used at low opacity

    // Accent — a single editorial terracotta. Slightly brighter in the dark.
    static let accent = Color(lightHex: 0xC1543A, darkHex: 0xE0694C)
    static let accentDeep = Color(lightHex: 0xA8442E, darkHex: 0xC9583D)
    static let accentSoft = Color(lightHex: 0xEFD9D0, darkHex: 0x3A271F) // tinted fills

    // Supporting tones (kept for API compatibility with existing views)
    static let accent2 = Color(lightHex: 0x4F6F64, darkHex: 0x7FA493)   // muted evergreen
    static let mint = Color(lightHex: 0x3E7D5A, darkHex: 0x5FB286)      // success

    static var cardStroke: Color { hairline.opacity(0.08) }
    static var card: Color { surface }
    /// Fill for unselected controls / sunken wells (adapts; replaces the old
    /// white-opacity fills that only worked on a dark background).
    static var control: Color { hairline.opacity(0.05) }
    static var controlStrong: Color { hairline.opacity(0.08) }
    /// Tint badge fill used behind small icons.
    static var iconChip: Color { accentSoft }

    /// Hero fill for the icon mark / primary button — a restrained two-stop of
    /// the accent itself, not a rainbow.
    static var heroGradient: LinearGradient {
        LinearGradient(colors: [accent, accentDeep], startPoint: .top, endPoint: .bottom)
    }

    /// Quiet tinted fill for selected states.
    static var subtleGradient: LinearGradient {
        LinearGradient(colors: [accentSoft, accentSoft], startPoint: .top, endPoint: .bottom)
    }
}

/// Calm editorial background — a warm flat field with one barely-there tonal
/// wash at the top. No floating neon blobs.
struct AmbientBackground: View {
    var body: some View {
        ZStack {
            Theme.bg.ignoresSafeArea()
            LinearGradient(
                colors: [Theme.accentSoft.opacity(0.35), Theme.bg.opacity(0)],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
        }
    }
}

/// Surface card — solid paper with a hairline border and a soft, low shadow.
/// (Name kept for API compatibility; the look is paper, not glass.)
struct GlassCard<Content: View>: View {
    var padding: CGFloat = 18
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Theme.hairline.opacity(0.06), radius: 14, x: 0, y: 8)
    }
}

/// Primary call-to-action — solid accent, white text, restrained shadow.
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.semibold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Theme.accent)
            )
            .shadow(color: Theme.accent.opacity(0.28), radius: 12, x: 0, y: 6)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}
