import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var exports: ExportStore
    @State private var selected: ExportRecord?

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                if exports.records.isEmpty {
                    emptyState
                } else {
                    list
                }
            }
            .navigationTitle("History")
            .toolbarBackground(.hidden, for: .navigationBar)
        }
        .sheet(item: $selected) { record in
            SavedExportView(record: record)
        }
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 12) {
                ForEach(exports.records) { record in
                    Button { selected = record } label: {
                        ExportRow(record: record)
                    }
                    .buttonStyle(.plain)
                    .contextMenu {
                        Button(role: .destructive) {
                            withAnimation { exports.delete(record) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions {
                        Button(role: .destructive) {
                            withAnimation { exports.delete(record) }
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                }
            }
            .padding(20)
            .padding(.bottom, 40)
        }
        .scrollIndicators(.hidden)
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle().fill(Theme.subtleGradient).frame(width: 88, height: 88)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("No exports yet")
                .font(.title3.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
            Text("Generate a Markdown export and it'll appear here, timestamped and ready to re-share.")
                .font(.subheadline)
                .foregroundStyle(Theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }
}

private struct ExportRow: View {
    let record: ExportRecord

    var body: some View {
        GlassCard(padding: 16) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Theme.heroGradient)
                        .frame(width: 46, height: 46)
                    Image(systemName: record.mode.symbol)
                        .font(.system(size: 19, weight: .semibold))
                        .foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(record.mode.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(Theme.textPrimary)
                        Text("· \(record.rangeTitle)")
                            .font(.subheadline)
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Text(Fmt.dateTime(record.createdAt))
                        .font(.footnote)
                        .foregroundStyle(Theme.textSecondary)
                    Text("\(record.dataPoints) data points · \(record.sectionCount) sections")
                        .font(.caption)
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }
}
