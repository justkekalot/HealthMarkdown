import SwiftUI

/// Pick exactly which Health metrics to request access to and export. Lets the
/// user pull just weight, blood pressure, etc. — and request read access scoped
/// to that selection.
struct CustomExportView: View {
    let range: DateRangeOption
    let customInterval: DateInterval

    @EnvironmentObject var health: HealthKitManager
    @EnvironmentObject var exports: ExportStore
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    @State private var selected: Set<String>
    @State private var includeRaw = true
    @State private var generateTask: Task<Void, Never>?
    @State private var showPreview = false
    @State private var showPaywall = false
    @State private var requested = false

    private struct Item: Identifiable { let id: String; let title: String; let section: HealthSection }

    private static let items: [Item] = {
        var out: [Item] = []
        for q in HealthCatalog.quantities { out.append(Item(id: q.id, title: q.title, section: q.section)) }
        for c in HealthCatalog.categories { out.append(Item(id: c.id, title: c.title, section: c.section)) }
        out.append(Item(id: HealthCatalog.workoutsID, title: "Workouts", section: .workouts))
        return out
    }()

    private static let sections: [HealthSection] =
        HealthSection.allCases.filter { sec in items.contains { $0.section == sec } }

    init(range: DateRangeOption, customInterval: DateInterval) {
        self.range = range
        self.customInterval = customInterval
        _selected = State(initialValue: Set(Self.items.map(\.id)))   // default: everything on
    }

    private var isFetching: Bool { if case .fetching = health.phase { return true }; return false }
    private var effectiveMode: ExportMode { includeRaw ? .full : .quick }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()
                List {
                    Section {
                        Toggle("Include raw samples", isOn: $includeRaw).tint(Theme.accent)
                        HStack {
                            Text("\(selected.count) of \(Self.items.count) selected")
                                .foregroundStyle(Theme.textSecondary)
                            Spacer()
                            Button("All") { selected = Set(Self.items.map(\.id)) }
                            Text("·").foregroundStyle(Theme.textSecondary)
                            Button("None") { selected = [] }
                        }
                        .font(.subheadline)
                    } footer: {
                        Text("Tip: tap “Request Health access” first so the metrics you pick are actually allowed to be read.")
                    }
                    ForEach(Self.sections, id: \.self) { section in
                        Section {
                            ForEach(Self.items.filter { $0.section == section }) { item in
                                Toggle(item.title, isOn: binding(for: item.id)).tint(Theme.accent)
                            }
                        } header: {
                            HStack {
                                Label(section.title, systemImage: section.symbol)
                                Spacer()
                                Button(allOn(section) ? "None" : "All") { toggleSection(section) }
                                    .font(.caption.weight(.semibold))
                            }
                        }
                    }
                }
                .scrollContentBackground(.hidden)
                .tint(Theme.accent)
                .safeAreaInset(edge: .bottom) { bottomBar }

                if isFetching, case let .fetching(progress, label) = health.phase {
                    ExportProgressOverlay(progress: progress,
                                          status: progress >= 1 ? label : "Reading \(label)…",
                                          onCancel: { generateTask?.cancel() })
                }
            }
            .navigationTitle("Custom export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
            .sheet(isPresented: $showPreview) {
                if let report = health.lastReport {
                    PreviewView(report: report, markdown: health.lastMarkdown)
                }
            }
            .sheet(isPresented: $showPaywall) { PaywallView() }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: 10) {
            Button {
                requested = true
                Task { await health.ensureReadAccess(for: HealthCatalog.readTypes(forIDs: selected)) }
            } label: {
                HStack {
                    Image(systemName: requested ? "checkmark" : "heart.text.square")
                    Text(requested ? "Access requested" : "Request Health access for selected")
                }
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.controlStrong))
                .foregroundStyle(Theme.textPrimary)
            }
            .buttonStyle(.plain)
            .disabled(selected.isEmpty)

            Button {
                guard purchases.canExport(mode: effectiveMode, range: range) else { showPaywall = true; return }
                generateTask = Task {
                    await health.generateReport(for: range, mode: effectiveMode, customInterval: customInterval, include: selected)
                    if health.phase == .done, health.lastReport != nil {
                        _ = exports.save(report: health.lastReport!, markdown: health.lastMarkdown)
                        showPreview = true
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "sparkles")
                    Text("Generate \(effectiveMode.title) export")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(selected.isEmpty)
        }
        .padding(16)
        .background(.ultraThinMaterial)
    }

    private func binding(for id: String) -> Binding<Bool> {
        Binding(get: { selected.contains(id) },
                set: { on in
                    if on { selected.insert(id) } else { selected.remove(id) }
                    requested = false
                })
    }

    private func allOn(_ section: HealthSection) -> Bool {
        Self.items.filter { $0.section == section }.allSatisfy { selected.contains($0.id) }
    }

    private func toggleSection(_ section: HealthSection) {
        let ids = Self.items.filter { $0.section == section }.map(\.id)
        if allOn(section) { ids.forEach { selected.remove($0) } } else { ids.forEach { selected.insert($0) } }
        requested = false
    }
}
