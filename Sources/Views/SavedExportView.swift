import SwiftUI
import UIKit

/// Action-focused viewer for a saved export (from History). We don't show the
/// raw Markdown — the file is for sharing or chatting with Gemma.
struct SavedExportView: View {
    let record: ExportRecord
    @EnvironmentObject var exports: ExportStore
    @Environment(\.dismiss) private var dismiss
    @State private var markdown = ""
    @State private var loading = true
    @State private var copied = false
    @State private var showShare = false
    @State private var showChat = false

    private var byteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(max(markdown.utf8.count, 0)), countStyle: .file)
    }

    /// Workout exports: "Cycling ×57" + the date span — clearer than data points.
    private var workoutDetail: String? {
        guard record.isWorkout else { return nil }
        let parts = [record.contents, record.period].compactMap { $0 }.filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                if loading {
                    ProgressView().tint(Theme.accent)
                } else {
                    ExportSummaryCard(
                        mode: record.mode,
                        rangeTitle: record.rangeTitle,
                        byteSize: byteSize,
                        statLeft: ("\(record.dataPoints)", "data points"),
                        statRight: ("\(record.sectionCount)", "sections"),
                        detail: workoutDetail,
                        onChat: { showChat = true },
                        onShare: { showShare = true },
                        onCopy: { copyToClipboard() },
                        copied: copied
                    )
                }
            }
            .navigationTitle("\(record.mode.title) · \(record.rangeTitle)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) {
                        exports.delete(record)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                    }
                    .tint(Theme.accent)
                }
            }
            .task {
                let url = exports.fileURL(for: record)
                let text = await Task.detached(priority: .userInitiated) {
                    (try? String(contentsOf: url, encoding: .utf8)) ?? "_Export file is missing._"
                }.value
                markdown = text
                loading = false
            }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [exports.fileURL(for: record)])
            }
            .sheet(isPresented: $showChat) {
                ExportChatView(title: record.isWorkout ? (record.contents ?? record.rangeTitle) : "\(record.mode.title) · \(record.rangeTitle)",
                               markdown: markdown,
                               digest: exports.digest(for: record))
            }
        }
    }

    private func copyToClipboard() {
        // Copy the .md file itself, not its text.
        let df = DateFormatter(); df.dateFormat = "yyyy-MM-dd"
        Clipboard.copyMarkdownFile(markdown, name: "AppleHealth-\(df.string(from: record.createdAt))")
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
    }
}
