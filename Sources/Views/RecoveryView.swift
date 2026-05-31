import SwiftUI
import HealthKit

/// "Morning Readiness" — an on-device recovery report comparing today vs
/// yesterday, narrated by an on-device model.
struct RecoveryView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var report: RecoveryReport?
    @State private var narrative: String = ""
    @State private var loading = true

    private let narrator: RecoveryNarrator = TemplateNarrator()

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        greeting
                        if loading {
                            loadingCard
                        } else if let report, report.hasData {
                            scoreCard(report)
                            narrativeCard
                            metricsCard(report)
                        } else {
                            emptyCard
                        }
                        disclaimer
                    }
                    .padding(20)
                    .padding(.bottom, 40)
                }
                .scrollIndicators(.hidden)
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        loading = true
        let r = await RecoveryAnalyzer.build(store: health.store)
        report = r
        narrative = await narrator.narrate(r)
        loading = false
    }

    // MARK: - Pieces

    private var greeting: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 32, weight: .bold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
            Text(Fmt.shortDate(Date()) + " · recovered overnight")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 8)
    }

    private var greetingText: String {
        let h = Calendar.current.component(.hour, from: Date())
        switch h {
        case 5..<12: return "Good morning."
        case 12..<18: return "Good afternoon."
        default: return "Good evening."
        }
    }

    private var loadingCard: some View {
        GlassCard {
            HStack(spacing: 12) {
                ProgressView().tint(Theme.accent)
                Text("Reading last night…")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
            }
        }
    }

    private func scoreCard(_ report: RecoveryReport) -> some View {
        GlassCard {
            HStack(spacing: 18) {
                if let s = report.score {
                    ZStack {
                        Circle().stroke(Theme.control, lineWidth: 10).frame(width: 96, height: 96)
                        Circle()
                            .trim(from: 0, to: CGFloat(s) / 100)
                            .stroke(Theme.accent, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                            .frame(width: 96, height: 96)
                        VStack(spacing: 0) {
                            Text("\(s)").font(.system(size: 30, weight: .bold, design: .rounded))
                                .foregroundStyle(Theme.textPrimary)
                            Text("/100").font(.caption2).foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(report.headline)
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("vs yesterday")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    private var narrativeCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles").foregroundStyle(Theme.accent)
                    Text("On-device summary")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                }
                Text(LocalizedStringKey(narrative))
                    .font(.callout)
                    .foregroundStyle(Theme.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func metricsCard(_ report: RecoveryReport) -> some View {
        GlassCard {
            VStack(spacing: 0) {
                ForEach(Array(report.metrics.enumerated()), id: \.element.id) { idx, m in
                    if idx > 0 { Divider().overlay(Theme.cardStroke) }
                    HStack(spacing: 14) {
                        Image(systemName: m.symbol)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 1) {
                            Text(m.title).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
                            if let y = m.yesterdayText {
                                Text("yesterday \(y)").font(.caption2).foregroundStyle(Theme.textSecondary)
                            }
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 1) {
                            Text(m.todayText).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                            if let d = m.deltaText {
                                Text(d).font(.caption2).foregroundStyle(trendColor(m.trend))
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
            }
        }
    }

    private func trendColor(_ t: TrendDirection) -> Color {
        switch t {
        case .better: return Theme.mint
        case .worse: return Theme.accent
        case .flat, .unknown: return Theme.textSecondary
        }
    }

    private var emptyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("Not enough overnight data yet")
                    .font(.headline).foregroundStyle(Theme.textPrimary)
                Text("Wear your watch to sleep for a night or two — then I can compare your recovery morning over morning.")
                    .font(.subheadline).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var disclaimer: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "info.circle")
                .font(.caption)
            Text("Generated entirely on your device. This is an AI-generated estimate, not medical advice — it can be wrong. Any complaints, take them up with the model. 🙂")
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textSecondary)
        .padding(.top, 4)
    }
}
