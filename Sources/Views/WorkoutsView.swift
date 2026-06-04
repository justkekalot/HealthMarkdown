import SwiftUI

/// Lists recent workouts, lets you multi-select, and exports the chosen ones as
/// a single Markdown file — share it, or chat about them with on-device Gemma.
struct WorkoutsView: View {
    @EnvironmentObject var health: HealthKitManager

    @State private var workouts: [WorkoutDetail] = []
    @State private var selected: Set<UUID> = []
    @State private var loading = true
    @State private var shareItem: ShareItem?
    @State private var chat: ChatPayload?

    /// How far back to list. Six months is plenty for a picker without flooding.
    private var since: Date { Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date() }

    private var selectedWorkouts: [WorkoutDetail] { workouts.filter { selected.contains($0.id) } }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                Group {
                    if loading {
                        loadingState
                    } else if workouts.isEmpty {
                        emptyState
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Workouts")
            .toolbar {
                if !workouts.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(selected.count == workouts.count ? "Clear" : "Select all") {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selected = selected.count == workouts.count ? [] : Set(workouts.map(\.id))
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
            .sheet(item: $chat) { payload in
                ExportChatView(title: payload.title, markdown: payload.markdown, digest: payload.digest)
            }
        }
    }

    // MARK: - List

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 10) {
                ForEach(workouts) { w in row(w) }
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
            .padding(.bottom, selected.isEmpty ? 24 : 96)
        }
        .scrollIndicators(.hidden)
    }

    private func row(_ w: WorkoutDetail) -> some View {
        let isOn = selected.contains(w.id)
        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isOn { selected.remove(w.id) } else { selected.insert(w.id) }
            }
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

    // MARK: - Export bar

    private var exportBar: some View {
        HStack(spacing: 12) {
            Text("\(selected.count) selected")
                .font(.subheadline.weight(.medium)).foregroundStyle(Theme.textPrimary)
            Spacer()
            Button { askGemma() } label: {
                Image(systemName: "bubble.left.and.text.bubble.right.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Circle().fill(Theme.accent.opacity(0.12)))
            }
            Button { share() } label: {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.arrow.up")
                    Text("Export").font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white)
                .padding(.vertical, 13).padding(.horizontal, 20)
                .background(Capsule().fill(Theme.accent))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: 12) {
            ProgressView().tint(Theme.accent)
            Text("Reading your workouts…").font(.subheadline).foregroundStyle(Theme.textSecondary)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "figure.run").font(.system(size: 34)).foregroundStyle(Theme.textSecondary)
            Text("No workouts in the last 6 months").font(.headline).foregroundStyle(Theme.textPrimary)
            Text("Recorded workouts from Apple Health show up here, ready to export.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
        }
        .padding(32)
    }

    // MARK: - Actions

    private func load() async {
        if workouts.isEmpty { loading = true }   // pull-to-refresh keeps the list visible
        let list = await health.fetchWorkoutList(since: since)
        workouts = list
        selected = selected.intersection(Set(list.map(\.id)))   // drop stale selections
        loading = false
    }

    private func share() {
        let md = WorkoutMarkdown.human(selectedWorkouts)
        let fm = FileManager.default
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        let url = fm.temporaryDirectory.appendingPathComponent("Workouts-\(df.string(from: Date())).md")
        if (try? md.data(using: .utf8)?.write(to: url)) != nil {
            shareItem = ShareItem(url: url)
            Haptics.success()
        }
    }

    private func askGemma() {
        let ws = selectedWorkouts
        chat = ChatPayload(title: "Workouts · \(ws.count)",
                           markdown: WorkoutMarkdown.human(ws),
                           digest: WorkoutMarkdown.digest(ws))
        Haptics.tap()
    }

    /// Identifiable payload so the chat sheet opens with the freshly-built export.
    private struct ChatPayload: Identifiable {
        let id = UUID()
        let title: String
        let markdown: String
        let digest: String
    }
}
