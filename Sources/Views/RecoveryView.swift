import SwiftUI
import HealthKit
import Combine

/// "Morning Readiness" — an on-device recovery report comparing today vs
/// yesterday, narrated by an on-device model.
struct RecoveryView: View {
    @EnvironmentObject var health: HealthKitManager
    @State private var report: RecoveryReport?
    @State private var stress: StressReport?
    @State private var loading = true
    @State private var showAsk = false

    /// Drives the realtime stress refresh while the screen is open.
    private let ticker = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        greeting
                        if loading {
                            loadingCard
                        } else if let report, report.hasData {
                            scoreCard(report)
                            if let stress, stress.hasData { stressCard(stress) }
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
            .onReceive(ticker) { _ in
                guard !loading else { return }
                Task { stress = await StressAnalyzer.build(store: health.store) }
            }
            .sheet(isPresented: $showAsk) {
                if let report { AskView(report: report) }
            }
        }
    }

    private func load() async {
        loading = true
        async let recovery = RecoveryAnalyzer.build(store: health.store)
        async let stressR = StressAnalyzer.build(store: health.store)
        report = await recovery
        stress = await stressR
        loading = false
    }

    // MARK: - Pieces

    private var greeting: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 32, weight: .bold, design: .serif))
                    .foregroundStyle(Theme.textPrimary)
                Text(Fmt.shortDate(Date()) + " · recovered overnight")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
            }
            Spacer(minLength: 8)
            if let report, report.hasData { askButton }
        }
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
                    Text("last night vs your baseline")
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
        }
    }

    // MARK: - Stress block

    private func stressCard(_ s: StressReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline) {
                    HStack(spacing: 8) {
                        Image(systemName: "gauge.with.dots.needle.bottom.50percent")
                            .foregroundStyle(Theme.accent)
                        Text("Stress")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                    }
                    Spacer()
                    if let n = s.now {
                        let band = StressReport.band(n)
                        HStack(spacing: 7) {
                            Circle().fill(barFill(n)).frame(width: 8, height: 8)
                            Text(band.label).font(.subheadline.weight(.medium)).foregroundStyle(Theme.textSecondary)
                            Text("\(n)").font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
                        }
                    }
                }

                stressStrip(s)

                HStack {
                    Text(s.buckets.first.map { Fmt.clock($0.hour) } ?? "")
                    Spacer()
                    Text("Now")
                }
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)

                HStack(spacing: 10) {
                    stressStat(value: s.currentHR.map { "\(Int($0.rounded())) bpm" } ?? "—", label: "Heart rate")
                    stressStat(value: s.restingHR.map { "\(Int($0.rounded())) bpm" } ?? "—", label: "Resting")
                    stressStat(value: s.dayAverage.map { "\($0)" } ?? "—", label: "24h avg")
                }
            }
        }
    }

    /// The intraday strip: one bar per hour, height and warmth scale with stress.
    private func stressStrip(_ s: StressReport) -> some View {
        HStack(alignment: .bottom, spacing: 3) {
            ForEach(s.buckets) { b in
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(b.stress == nil ? Theme.control : barFill(b.stress!))
                    .frame(maxWidth: .infinity)
                    .frame(height: barHeight(b.stress))
            }
        }
        .frame(height: 56, alignment: .bottom)
    }

    private func stressStat(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
            Text(label).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 9)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.control))
    }

    private func barHeight(_ stress: Int?) -> CGFloat {
        guard let stress else { return 6 }     // faint track for a no-data hour
        return 10 + (56 - 10) * CGFloat(min(100, max(0, stress))) / 100
    }

    /// Warm fill on a low→high ramp (soft terracotta → deep red), matching the
    /// reference design.
    private func barFill(_ stress: Int) -> Color {
        switch StressReport.band(stress).level {
        case .low:      return Theme.accent.opacity(0.4)
        case .moderate: return Theme.accent.opacity(0.7)
        case .elevated: return Theme.accent
        case .high:     return Theme.accentDeep
        }
    }

    /// Compact pill in the header — opens the on-device chat about today.
    private var askButton: some View {
        Button { showAsk = true } label: {
            HStack(spacing: 6) {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                Text("Ask")
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 9)
            .background(Capsule().fill(Theme.accent))
        }
        .buttonStyle(.plain)
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
                            if let sub = m.subtitle {
                                Text(sub).font(.caption2).foregroundStyle(Theme.textSecondary)
                            } else if let y = m.yesterdayText {
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
