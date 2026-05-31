import SwiftUI

struct DashboardView: View {
    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var exports: ExportStore
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selectedRange: DateRangeOption = .last30Days
    @State private var selectedMode: ExportMode = .quick
    @State private var showPreview = false
    @State private var showPaywall = false
    @State private var showCustomRange = false
    // Custom range bounds (default: last 24h), used when selectedRange == .custom.
    @State private var customStart = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()
    /// The record produced by the most recent Generate with the *current*
    /// inputs. Cleared whenever mode/range change so a stale result never lingers.
    @State private var freshRecord: ExportRecord?

    private var isFetching: Bool {
        if case .fetching = health.phase { return true }
        return false
    }

    private var customInterval: DateInterval {
        DateInterval(start: min(customStart, customEnd), end: max(customStart, customEnd))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    stepHeader(1, "What to export")
                    modeSelector

                    stepHeader(2, "Over which period")
                    rangeChips

                    stepHeader(3, "Generate")
                    actionArea

                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 40)
            }
            .scrollIndicators(.hidden)
            .background(Color.clear)
            .navigationTitle("New Export")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(isPresented: $showPreview) {
            if let report = health.lastReport {
                PreviewView(report: report, markdown: health.lastMarkdown)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView()
        }
        .sheet(isPresented: $showCustomRange) {
            CustomRangeSheet(start: $customStart, end: $customEnd)
        }
    }

    // MARK: - Step header

    private func stepHeader(_ n: Int, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text("\(n)")
                .font(.caption.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 22, height: 22)
                .background(Circle().fill(Theme.accent.opacity(0.85)))
            Text(title)
                .font(.headline)
                .foregroundStyle(Theme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Step 1: mode (two side-by-side cards)

    private var modeSelector: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                ForEach(ExportMode.allCases) { mode in
                    modeCard(mode)
                }
            }
            // Explanation for the currently-selected mode, below the cards.
            HStack(spacing: 8) {
                Image(systemName: "info.circle")
                    .font(.caption)
                    .foregroundStyle(Theme.textSecondary)
                Text(selectedMode.subtitle)
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
            }
            .padding(.horizontal, 4)
            .transition(.opacity)
            .id(selectedMode)
        }
    }

    private func modeCard(_ mode: ExportMode) -> some View {
        let selected = selectedMode == mode
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedMode = mode
                invalidateResult()
            }
        } label: {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    ZStack {
                        RoundedRectangle(cornerRadius: 11, style: .continuous)
                            .fill(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.control))
                            .frame(width: 38, height: 38)
                        Image(systemName: mode.symbol)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(selected ? Color.white : Theme.accent)
                    }
                    Spacer()
                    Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundStyle(selected ? Theme.accent : Theme.textSecondary.opacity(0.5))
                }
                Text(mode.title)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text(mode.shortTag)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(Theme.textSecondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(selected ? Theme.subtleGradient : LinearGradient(colors: [Theme.card], startPoint: .top, endPoint: .bottom))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Theme.accent.opacity(0.6) : Theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Step 2: range (single horizontal chip row)

    private var rangeChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(DateRangeOption.allCases) { option in
                    rangeChip(option)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 2)
        }
        .scrollClipDisabled()
    }

    private func rangeChip(_ option: DateRangeOption) -> some View {
        let selected = selectedRange == option
        return Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                selectedRange = option
                invalidateResult()
            }
            if option.isCustom { showCustomRange = true }
        } label: {
            HStack(spacing: 6) {
                if option.isCustom {
                    Image(systemName: "calendar")
                        .font(.caption.weight(.semibold))
                }
                Text(option.isCustom && selected ? customChipTitle : option.title)
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(selected ? .white : Theme.textPrimary)
            .padding(.vertical, 10)
            .padding(.horizontal, 16)
            .background(
                Capsule().fill(selected ? AnyShapeStyle(Theme.accent) : AnyShapeStyle(Theme.control))
            )
            .overlay(
                Capsule().stroke(selected ? Color.clear : Theme.cardStroke, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var customChipTitle: String {
        "\(Fmt.shortDate(customInterval.start)) – \(Fmt.shortDate(customInterval.end))"
    }

    // MARK: - Step 3: action / progress / result

    @ViewBuilder
    private var actionArea: some View {
        if isFetching, case let .fetching(progress, label) = health.phase {
            progressCard(progress: progress, label: label)
        } else if let record = freshRecord, let report = health.lastReport {
            resultCard(record: record, report: report)
        } else {
            generateButton
        }
    }

    private var generateButton: some View {
        VStack(spacing: 10) {
            Button {
                // First export is free; after that, require the one-time unlock.
                guard purchases.canExport else {
                    showPaywall = true
                    return
                }
                Task {
                    await health.generateReport(for: selectedRange, mode: selectedMode, customInterval: customInterval)
                    if health.phase == .done, let report = health.lastReport {
                        freshRecord = exports.save(report: report, markdown: health.lastMarkdown)
                        purchases.markFreeExportUsed()
                    }
                }
            } label: {
                HStack {
                    Image(systemName: purchases.canExport ? "sparkles" : "lock.fill")
                    Text("Generate \(selectedMode.title) export")
                }
            }
            .buttonStyle(PrimaryButtonStyle())

            if !purchases.isUnlocked {
                Text(purchases.freeExportUsed
                     ? "Free export used — unlock for unlimited."
                     : "Your first export is free.")
                    .font(.footnote)
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private func progressCard(progress: Double, label: String) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    ProgressView().tint(Theme.accent)
                    // The final formatting step supplies a full sentence; the
                    // per-metric fetch steps are bare names, so prefix "Reading".
                    Text(progress >= 1 ? label : "Reading \(label)…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textPrimary)
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.subheadline.monospacedDigit())
                        .foregroundStyle(Theme.textSecondary)
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Theme.control)
                        Capsule()
                            .fill(Theme.accent)
                            .frame(width: max(8, geo.size.width * progress))
                            .animation(.easeInOut(duration: 0.3), value: progress)
                    }
                }
                .frame(height: 8)
            }
        }
    }

    private func resultCard(record: ExportRecord, report: HealthReport) -> some View {
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
                        Text("\(report.mode.title) export ready")
                            .font(.headline)
                            .foregroundStyle(Theme.textPrimary)
                        Text("\(report.totalDataPoints) data points • \(report.sectionsWithData.count) sections • saved to History")
                            .font(.footnote)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }

                FlowChips(sections: report.sectionsWithData)

                // Share is the primary action; preview is secondary.
                Button {
                    showPreview = true
                } label: {
                    HStack {
                        Image(systemName: "doc.text.magnifyingglass")
                        Text("Preview & Share")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())

                Button {
                    withAnimation { invalidateResult() }
                } label: {
                    Text("Start another export")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.98)))
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

    /// Drop the stale result so the screen returns to the Generate button when
    /// inputs change (or the user wants a new export).
    private func invalidateResult() {
        freshRecord = nil
        if health.phase == .done { health.phase = .idle }
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
                .foregroundStyle(Theme.accent)
                .padding(.vertical, 7)
                .padding(.horizontal, 10)
                .background(
                    Capsule().fill(Theme.iconChip)
                )
            }
        }
    }
}

/// Sheet for picking a custom start/end window.
struct CustomRangeSheet: View {
    @Binding var start: Date
    @Binding var end: Date
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                Form {
                    DatePicker("Start", selection: $start, in: ...end, displayedComponents: [.date, .hourAndMinute])
                    DatePicker("End", selection: $end, in: start..., displayedComponents: [.date, .hourAndMinute])
                }
                .scrollContentBackground(.hidden)
                .tint(Theme.accent)
            }
            .navigationTitle("Custom period")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(Theme.accent)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
