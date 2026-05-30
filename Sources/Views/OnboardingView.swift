import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var appear = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Hero mark
            ZStack {
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: Theme.accent.opacity(0.5), radius: 30, x: 0, y: 18)
                Image(systemName: "heart.text.square.fill")
                    .font(.system(size: 58, weight: .bold))
                    .foregroundStyle(.white)
            }
            .scaleEffect(appear ? 1 : 0.7)
            .opacity(appear ? 1 : 0)

            VStack(spacing: 12) {
                Text("Health → Markdown")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .multilineTextAlignment(.center)

                Text("Turn everything in Apple Health into one clean Markdown file — ready to hand to your AI assistant.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            .padding(.top, 28)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            VStack(spacing: 14) {
                FeatureRow(icon: "lock.shield.fill", title: "Private by design", subtitle: "Read on-device. Nothing leaves your phone unless you share it.")
                FeatureRow(icon: "square.grid.2x2.fill", title: "40+ metrics", subtitle: "Activity, heart, sleep, vitals, nutrition, workouts & more.")
                FeatureRow(icon: "doc.text.fill", title: "Agent-ready format", subtitle: "Structured tables an LLM can read at a glance.")
            }
            .padding(.top, 36)
            .padding(.horizontal, 24)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 24)

            Spacer()

            VStack(spacing: 14) {
                if health.authState == .unavailable {
                    Text("Health data isn't available on this device.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.accent)
                } else {
                    Button {
                        Task { await health.requestAuthorization() }
                    } label: {
                        HStack {
                            if health.authState == .requesting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "heart.fill")
                                Text("Connect Apple Health")
                            }
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(health.authState == .requesting)

                    if health.authState == .denied {
                        Text("Couldn't get access. You can grant it later in Settings → Health → Data Access.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .multilineTextAlignment(.center)
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 24)
            .opacity(appear ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7).delay(0.1)) {
                appear = true
            }
        }
    }
}

private struct FeatureRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Theme.subtleGradient)
                    .frame(width: 46, height: 46)
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer()
        }
    }
}
