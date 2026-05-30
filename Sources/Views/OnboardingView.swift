import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var appear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Spacer()

            // Wordmark — editorial, left-aligned.
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Theme.heroGradient)
                        .frame(width: 54, height: 54)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 26, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("HealthMarkdown")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundStyle(Theme.textSecondary)
                    .tracking(0.5)
            }
            .scaleEffect(appear ? 1 : 0.9, anchor: .leading)
            .opacity(appear ? 1 : 0)

            VStack(alignment: .leading, spacing: 16) {
                Text("Your health,\nas one clean file.")
                    .font(.system(size: 40, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text("HealthMarkdown reads everything in Apple Health and writes it into a single Markdown document — built to hand straight to an AI assistant.")
                    .font(.body)
                    .foregroundStyle(Theme.textSecondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 28)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 16)

            VStack(alignment: .leading, spacing: 4) {
                FeatureRow(icon: "lock.fill", title: "Private by design", subtitle: "Read on-device. Nothing leaves your phone unless you share it.")
                Divider().overlay(Theme.cardStroke)
                FeatureRow(icon: "square.stack.3d.up.fill", title: "40+ metrics", subtitle: "Activity, heart, sleep, vitals, nutrition, workouts & more.")
                Divider().overlay(Theme.cardStroke)
                FeatureRow(icon: "doc.plaintext.fill", title: "Agent-ready format", subtitle: "Structured tables an LLM can read at a glance.")
            }
            .padding(.top, 40)
            .opacity(appear ? 1 : 0)
            .offset(y: appear ? 0 : 24)

            Spacer()

            VStack(alignment: .leading, spacing: 14) {
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
                    } else {
                        Text("One tap. Read-only. Revoke anytime in Settings.")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                }
            }
            .opacity(appear ? 1 : 0)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 28)
        .onAppear {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.8).delay(0.1)) {
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
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.textPrimary)
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }
}
