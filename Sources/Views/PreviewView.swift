import SwiftUI
import UIKit

struct PreviewView: View {
    let report: HealthReport
    /// Pre-generated Markdown (built off the main thread by HealthKitManager).
    let markdown: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var showChat = false
    /// Bound to .sheet(item:) so the share sheet can only present once the file
    /// actually exists — fixes the empty grey sheet right after generation.
    @State private var shareItem: ShareItem?

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ExportSummaryCard(
                    mode: report.mode,
                    rangeTitle: report.range.title,
                    byteSize: byteSize,
                    statLeft: report.mode.includesRaw ? ("\(report.rawSampleCount)", "raw samples")
                                                      : ("\(report.totalDataPoints)", "data points"),
                    statRight: report.mode.includesRaw ? ("\(report.rawSeries.count + report.rawCategorySeries.count)", "metrics")
                                                       : ("\(report.sectionsWithData.count)", "sections"),
                    onChat: { showChat = true },
                    onShare: { share() },
                    onCopy: { copyToClipboard() },
                    copied: copied
                )
            }
            .navigationTitle("Export ready")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
            .sheet(item: $shareItem) { item in
                ShareSheet(items: [item.url])
            }
            .sheet(isPresented: $showChat) {
                ExportChatView(title: "\(report.mode.title) · \(report.range.title)",
                               markdown: markdown,
                               digest: ModelDigest.make(from: report))
            }
        }
    }

    private func copyToClipboard() {
        // Copy the .md file itself, not its text — reuses the share temp file.
        if let url = writeTempFile(markdown) { Clipboard.copyFile(at: url) }
        withAnimation { copied = true }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) { withAnimation { copied = false } }
    }

    /// Write the file on demand and present the share sheet only when it exists.
    private func share() {
        if let url = writeTempFile(markdown) {
            shareItem = ShareItem(url: url)
        }
    }

    private var byteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(markdown.utf8.count), countStyle: .file)
    }

    private func writeTempFile(_ contents: String) -> URL? {
        let fm = FileManager.default
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        let name = "AppleHealth-\(df.string(from: report.generatedAt)).md"
        let url = fm.temporaryDirectory.appendingPathComponent(name)
        do {
            try contents.data(using: .utf8)?.write(to: url)
            return url
        } catch {
            return nil
        }
    }
}

/// Identifiable wrapper so a file URL can drive `.sheet(item:)`.
struct ShareItem: Identifiable {
    let url: URL
    var id: String { url.path }
}

/// Action-focused summary of a generated export. We never show the raw Markdown
/// (it's noise for the user); the file is for sharing / chatting, not reading.
struct ExportSummaryCard: View {
    let mode: ExportMode
    let rangeTitle: String
    let byteSize: String
    let statLeft: (String, String)
    let statRight: (String, String)
    /// When set (workout exports), shown instead of the two-stat box — a plain
    /// description like "Cycling ×57\n14 Jun 2020 – 14 Jun 2026".
    var detail: String? = nil
    let onChat: () -> Void
    let onShare: () -> Void
    let onCopy: () -> Void
    let copied: Bool

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            VStack(spacing: 18) {
                ZStack {
                    Circle().fill(Theme.heroGradient).frame(width: 76, height: 76)
                        .shadow(color: Theme.accent.opacity(0.3), radius: 14, x: 0, y: 8)
                    Image(systemName: "checkmark")
                        .font(.system(size: 34, weight: .bold)).foregroundStyle(.white)
                }
                VStack(spacing: 4) {
                    Text("\(mode.title) export ready")
                        .font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
                    Text("\(rangeTitle) · \(byteSize)")
                        .font(.subheadline).foregroundStyle(Theme.textSecondary)
                }

                if let detail {
                    Text(detail)
                        .font(.subheadline).foregroundStyle(Theme.textPrimary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 14).padding(.horizontal, 22)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.control))
                } else {
                    HStack(spacing: 14) {
                        stat(statLeft)
                        Divider().frame(height: 32).overlay(Theme.cardStroke)
                        stat(statRight)
                    }
                    .padding(.vertical, 14).padding(.horizontal, 22)
                    .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.control))
                }

                VStack(spacing: 10) {
                    Button(action: onChat) {
                        HStack {
                            Image(systemName: "sparkles")
                            Text("Ask Gemma about this")
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())

                    HStack(spacing: 10) {
                        secondary(icon: "square.and.arrow.up", label: "Share", action: onShare)
                        secondary(icon: copied ? "checkmark" : "doc.on.doc",
                                  label: copied ? "Copied" : "Copy", action: onCopy)
                    }
                }
            }
            .padding(24)
            .background(
                RoundedRectangle(cornerRadius: 24, style: .continuous).fill(Theme.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1)
            )
            .shadow(color: Theme.hairline.opacity(0.06), radius: 16, x: 0, y: 10)
            .padding(.horizontal, 20)
            Spacer()
            Spacer()
        }
    }

    private func stat(_ s: (String, String)) -> some View {
        VStack(spacing: 2) {
            Text(s.0).font(.title3.weight(.bold)).foregroundStyle(Theme.textPrimary)
            Text(s.1).font(.caption2).foregroundStyle(Theme.textSecondary)
        }
        .frame(minWidth: 70)
    }

    private func secondary(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                Text(label)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(Theme.textPrimary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.controlStrong))
            .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Theme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
    }
}

/// UIKit share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
