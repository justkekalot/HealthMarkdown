import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var exports: ExportStore
    @State private var selectedRange: DateRangeOption = .last30Days
    @State private var selectedMode: ExportMode = .quick
    @State private var showPreview = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    intro

                    modePicker

                    rangePicker

                    if case let .fetching(progress, label) = health.phase {
                        progressCard(progress: progress, label: label)
                    } else {
                        generateButton
                    }

                    if let report = health.lastReport, health.phase == .done || health.phase == .idle {
                        resultCard(report)
                    }

                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationTitle("Export")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPreview) {
            if let report = health.lastReport {
                PreviewView(report: report)
            }
        }
    }

    // MARK: - Pieces

    private var intro: some View {
        Text("Choose what to export and over which window.")
            .font(.subheadline)
            .foregroundStyle(Theme.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("EXPORT TYPE")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(1.2)

            VStack(spacing: 10) {
                ForEach(ExportMode.allCases) { mode in
                    modeRow(mode)
                }
            }
        }
    }

    private func modeRow(_ mode: ExportMode) -> some View {
        let selected = selectedMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMode = mode
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(selected ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Color.white.opacity(0.07)))
                        .frame(width: 42, height: 42)
                    Image(systemName: mode.symbol)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(mode.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(mode.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Theme.accent)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.subtleGradient : LinearGradient(colors: [Theme.card], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var rangePicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("TIME WINDOW")
                .font(.caption.weight(.semibold))
                .foregroundStyle(Theme.textSecondary)
                .tracking(1.2)

            VStack(spacing: 10) {
                ForEach(DateRangeOption.allCases) { option in
                    rangeRow(option)
                }
            }
        }
    }

    private func rangeRow(_ option: DateRangeOption) -> some View {
        let selected = selectedRange == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRange = option
            }
        } label: {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(selected ? Color.clear : Theme.cardStroke, lineWidth: 1.5)
                        .background(Circle().fill(selected ? AnyShapeStyle(Theme.heroGradient) : AnyShapeStyle(Color.clear)))
                        .frame(width: 24, height: 24)
                    if selected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(option.title)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(Theme.textPrimary)
                    Text(option.subtitle)
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(selected ? Theme.subtleGradient : LinearGradient(colors: [Theme.card], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(selected ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var generateButton: some View {
        Button {
            Task {
                await health.generateReport(for: selectedRange, mode: selectedMode)
                if health.phase == .done, let report = health.lastReport {
                    let md = MarkdownGenerator.generate(from: report)
                    exports.save(report: report, markdown: md)
                    showPreview = true
                }
            }
        } label: {
            HStack {
                Image(systemName: "sparkles")
                Text("Generate \(selectedMode.title) Markdown")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private func progressCard(progress: Double, label: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ProgressView().tint(Theme.accent)
                    Text("Reading \(label)…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.08))
                        Capsule()
                            .fill(Theme.heroGradient)
                            .frame(width: max(8, geo.size.width * progress))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func resultCard(_ report: HealthReport) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle().fill(Theme.subtleGradient).frame(width: 44, height: 44)
                        Image(systemName: "checkmark")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(Theme.mint)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Ready")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(report.totalDataPoints) data points • \(report.sectionsWithData.count) sections")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                // Section chips
                FlowChips(sections: report.sectionsWithData)

                Button {
                    showPreview = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview & Share")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
            }
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill")
                .font(.caption)
            Text("Everything is read on-device. Nothing is uploaded.")
                .font(.caption)
        }
        .foregroundStyle(Theme.textSecondary)
        .frame(maxWidth: .infinity)
        .padding(.top, 4)
    }
}

/// Simple wrapping chip layout for section labels.
struct FlowChips: View {
    let sections: [HealthSection]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 96), spacing: 8)]
        LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
            ForEach(sections) { section in
                HStack(spacing: 6) {
                    Image(systemName: section.symbol)
                        .font(.caption2)
                    Text(section.title)
                        .font(.caption.weight(.medium))
                        .lineLimit(1)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    Capsule().fill(Color.white.opacity(0.07))
                )
                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
            }
        }
    }
}
