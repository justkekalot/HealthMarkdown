import SwiftUI

/// Lists workouts (date-range selectable, all-time by default), multi-select,
/// and exports the chosen ones as one Markdown file — share it or chat with
/// on-device Gemma. GPS-route metrics (max speed, elevation) are pulled lazily
/// at export time for the selected workouts only.
struct WorkoutsView: View {
    @EnvironmentObject var health: HealthKitManager

    @State private var workouts: [WorkoutDetail] = []
    @State private var selected: Set<UUID> = []
    @State private var activeTypes: Set<String> = []   // empty = all types
    @State private var range: DateRange = .all
    @State private var customStart = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var customEnd = Date()
    @State private var showCustom = false
    @State private var loading = true
    @State private var exporting = false
    @State private var shareItem: ShareItem?
    @State private var chat: ChatPayload?

    enum DateRange: String, CaseIterable, Identifiable {
        case month, three, six, year, all, custom
        var id: String { rawValue }
        var label: String {
            switch self {
            case .month: return "Last month"
            case .three: return "Last 3 months"
            case .six: return "Last 6 months"
            case .year: return "Last year"
            case .all: return "All time"
            case .custom: return "Custom range"
            }
        }
        func start(now: Date, calendar: Calendar, custom: Date) -> Date {
            switch self {
            case .month: return calendar.date(byAdding: .month, value: -1, to: now) ?? now
            case .three: return calendar.date(byAdding: .month, value: -3, to: now) ?? now
            case .six:   return calendar.date(byAdding: .month, value: -6, to: now) ?? now
            case .year:  return calendar.date(byAdding: .year, value: -1, to: now) ?? now
            case .all:   return .distantPast
            case .custom: return custom
            }
        }
    }

    private var selectedWorkouts: [WorkoutDetail] { workouts.filter { selected.contains($0.id) } }

    private var types: [(name: String, symbol: String, count: Int)] {
        var order: [String] = [], counts: [String: Int] = [:], symbols: [String: String] = [:]
        for w in workouts {
            if counts[w.activityName] == nil { order.append(w.activityName); symbols[w.activityName] = w.symbol }
            counts[w.activityName, default: 0] += 1
        }
        return order.map { (name: $0, symbol: symbols[$0] ?? "figure.run", count: counts[$0] ?? 0) }
            .sorted { $0.count > $1.count || ($0.count == $1.count && $0.name < $1.name) }
    }

    private var filtered: [WorkoutDetail] {
        activeTypes.isEmpty ? workouts : workouts.filter { activeTypes.contains($0.activityName) }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                VStack(spacing: 0) {
                    ScreenHeader(title: "Workouts", subtitle: "Select sessions, export the full data")
                        .padding(.horizontal, 20).padding(.bottom, 6)
                    rangeRow
                    if !types.isEmpty { filterBar }
                    content
                }
                if exporting { progressOverlay }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                if !workouts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        let ids = Set(filtered.map(\.id))
                        let allSelected = !ids.isEmpty && ids.isSubset(of: selected)
                        Button(allSelected ? "Clear" : "Select all") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                if allSelected { selected.subtract(ids) } else { selected.formUnion(ids) }
                            }
                        }
                        .foregroundStyle(Theme.accent)
                    }
                }
            }
            .task { await load() }
            .refreshable { await load() }
            .safeAreaInset(edge: .bottom) { if !selected.isEmpty { exportBar } }
            .sheet(item: $shareItem) { ShareSheet(items: [$0.url]) }
            .sheet(isPresented: $showCustom) { customSheet }
            .sheet(item: $chat) { payload in
                ExportChatView(title: payload.title, markdown: payload.markdown, digest: payload.digest)
            }
        }
    }

    // MARK: - Header (date range + type chips)

    private var rangeRow: some View {
        HStack {
            Menu {
                ForEach(DateRange.allCases) { r in
                    Button { select(r) } label: {
                        if range == r { Label(r.label, systemImage: "checkmark") } else { Text(r.label) }
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "calendar")
                    Text(rangeLabel).font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down").font(.caption2)
                }
                .foregroundStyle(Theme.textPrimary)
                .padding(.vertical, 9).padding(.horizontal, 14)
                .background(Capsule().fill(Theme.control))
                .overlay(Capsule().stroke(Theme.cardStroke, lineWidth: 1))
            }
            Spacer()
            if !workouts.isEmpty {
                Text("\(workouts.count) total").font(.caption).foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(.horizontal, 16).padding(.top, 8).padding(.bottom, 6)
    }

    private var rangeLabel: String {
        range == .custom ? "\(Fmt.shortDate(customStart)) – \(Fmt.shortDate(customEnd))" : range.label
    }

    // The chip row is its own horizontal scroll region, kept clearly separate
    // (and pinned to a real height) from the vertical list so the two scroll
    // gestures don't fight.
    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                chip(label: "All", symbol: "square.grid.2x2", active: activeTypes.isEmpty) {
                    withAnimation(.easeInOut(duration: 0.15)) { activeTypes = [] }
                }
                ForEach(types, id: \.name) { t in
                    chip(label: "\(t.name) (\(t.count))", symbol: t.symbol, active: activeTypes.contains(t.name)) {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            if activeTypes.contains(t.name) { activeTypes.remove(t.name) } else { activeTypes.insert(t.name) }
                        }
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .frame(height: 60)
    }

    private func chip(label: String, symbol: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 7) {
                Image(systemName: symbol).font(.footnote)
                Text(label).font(.subheadline.weight(.medium))
            }
            .foregroundStyle(active ? Color.white : Theme.textPrimary)
            .padding(.vertical, 10).padding(.horizontal, 15)
            .background(Capsule().fill(active ? Theme.accent : Theme.control))
            .overlay(Capsule().stroke(active ? Color.clear : Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Content

    @ViewBuilder private var content: some View {
        if loading {
            loadingState
        } else if workouts.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(filtered) { w in row(w) }
                }
                .padding(.horizontal, 16).padding(.top, 4)
                .padding(.bottom, selected.isEmpty ? 24 : 96)
            }
            .scrollIndicators(.hidden)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private func row(_ w: WorkoutDetail) -> some View {
        let isOn = selected.contains(w.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) { if isOn { selected.remove(w.id) } else { selected.insert(w.id) } }
            Haptics.tap()
        } label: {
            HStack(spacing: 14) {
                Image(systemName: w.symbol)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 34, height: 34)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
                VStack(alignment: .leading, spacing: 2) {
                    Text(w.activityName).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                    Text("\(Fmt.dateTime(w.start)) · \(Fmt.duration(w.duration))")
                        .font(.caption).foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                if let stat = rightStat(w) {
                    Text(stat).font(.caption.weight(.medium)).foregroundStyle(Theme.textSecondary)
                }
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundStyle(isOn ? Theme.accent : Theme.textSecondary.opacity(0.4))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.control))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isOn ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: isOn ? 1.5 : 1))
        }
        .buttonStyle(.plain)
    }

    private func rightStat(_ w: WorkoutDetail) -> String? {
        if let d = w.distanceKm, d > 0 { return "\(Fmt.number(d, precision: 1)) km" }
        if let e = w.energyKcal, e > 0 { return "\(Fmt.number(e, precision: 0)) kcal" }
        return nil
    }

    // MARK: - Export bar + overlay

    private var exportBar: some View {
        HStack(spacing: 12) {
            Text("\(selected.count) selected")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button { Task { await export(share: false) } } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
            }
            Button { Task { await export(share: true) } } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 13).padding(.horizontal, 20)
                .background(Capsule().fill(Theme.accent))
            }
        }
        .disabled(exporting)
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private var progressOverlay: some View {
        ZStack {
            Color.black.opacity(0.35).ignoresSafeArea()
            VStack(spacing: 12) {
                ProgressView().tint(.white)
                Text("Pulling routes & building export…").font(.subheadline).foregroundStyle(.white)
            }
            .padding(24)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.ultraThinMaterial))
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.accent)
            Text("Reading your workouts…").font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run").font(.system(size: 34)).foregroundStyle(Theme.textSecondary)
            Text("No workouts in this range").font(.headline).foregroundStyle(Theme.textPrimary)
            Text("Pick a wider date range, or record a workout in Apple Health.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Custom range sheet

    private var customSheet: some View {
        NavigationStack {
            Form {
                DatePicker("From", selection: $customStart, in: ...customEnd, displayedComponents: .date)
                DatePicker("To", selection: $customEnd, in: customStart...Date(), displayedComponents: .date)
            }
            .navigationTitle("Custom range")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showCustom = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Apply") { range = .custom; showCustom = false; Task { await load() } }.fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Actions

    private func select(_ r: DateRange) {
        if r == .custom { showCustom = true; return }
        range = r
        Task { await load() }
    }

    private func load() async {
        if workouts.isEmpty { loading = true }
        let cal = Calendar.current, now = Date()
        let start = range.start(now: now, calendar: cal, custom: customStart)
        let end = range == .custom ? customEnd : now
        let list = await health.fetchWorkoutList(since: start, now: end)
        workouts = list
        selected = selected.intersection(Set(list.map(\.id)))
        loading = false
    }

    /// Enrich the current selection with GPS-route metrics, then build & deliver.
    private func export(share: Bool) async {
        guard !selected.isEmpty, !exporting else { return }
        exporting = true
        var ws = selectedWorkouts
        await health.ensureRouteAccess()
        let metrics = await health.routeMetrics(for: ws.map(\.id))
        for i in ws.indices {
            if let m = metrics[ws[i].id] {
                ws[i].routeMaxSpeedKmh = m.maxSpeedKmh
                ws[i].routeElevationGainM = m.elevationGainM
                ws[i].routeElevationLossM = m.elevationLossM
            }
        }
        exporting = false

        if share {
            let md = WorkoutMarkdown.human(ws)
            let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("Workouts-\(df.string(from: Date())).md")
            if (try? md.data(using: .utf8)?.write(to: url)) != nil { shareItem = ShareItem(url: url); Haptics.success() }
        } else {
            chat = ChatPayload(title: "Workouts · \(ws.count)",
                               markdown: WorkoutMarkdown.human(ws), digest: WorkoutMarkdown.digest(ws))
            Haptics.tap()
        }
    }

    private struct ChatPayload: Identifiable {
        let id = UUID()
        let title: String
        let markdown: String
        let digest: String
    }
}
