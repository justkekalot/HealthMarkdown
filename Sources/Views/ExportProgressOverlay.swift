import SwiftUI

/// The single, shared export-progress UI used by BOTH the Workouts and Health
/// exports — a centred modal card over a dimmed backdrop: title + percent, an
/// animated bar, a live status line, and a Cancel button. One design, two screens.
struct ExportProgressOverlay: View {
    var title: String = "Building export"
    let progress: Double
    let status: String
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.5).ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up.fill").font(.title3).foregroundStyle(Theme.accent)
                    Text(title).font(.headline).foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.monospacedDigit().weight(.semibold))
                        .foregroundStyle(Theme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.control)
                        Capsule().fill(Theme.accent)
                            .frame(width: max(8, geo.size.width * min(max(progress, 0.02), 1)))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
                Text(status.isEmpty ? "Preparing…" : status)
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button(role: .destructive, action: onCancel) {
                    Text("Cancel export").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(Theme.accent)
            }
            .padding(22)
            .frame(maxWidth: 330)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.bg))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 24, y: 10)
            .padding(40)
        }
    }
}
