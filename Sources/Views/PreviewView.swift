import SwiftUI
import UIKit

struct PreviewView: View {
    let report: HealthReport
    /// Pre-generated Markdown (built off the main thread by HealthKitManager).
    let markdown: String
    @Environment(\.dismiss) private var dismiss
    @State private var copied = false
    @State private var showShare = false
    @State private var exportURL: URL?

    /// Big exports (full mode over a long window) can be hundreds of KB —
    /// rendering that as one selectable Text is slow and pointless. Above this
    /// size we show a file card instead of the raw text.
    private var isLarge: Bool { markdown.utf8.count > 60_000 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if isLarge {
                    largeFileCard
                } else {
                    ScrollView {
                        Text(markdown)
                            .font(.system(.footnote, design: .monospaced))
                            .foregroundStyle(Theme.textPrimary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(Color.white.opacity(0.05))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .stroke(Theme.cardStroke, lineWidth: 1)
                            )
                            .padding(16)
                            .padding(.bottom, 120)
                    }
                    .scrollIndicators(.hidden)
                }

                VStack {
                    Spacer()
                    actionBar
                }
            }
            .navigationTitle("Markdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Theme.textPrimary)
                }
            }
            .task {
                // File write is the only work here now; markdown is already built.
                exportURL = writeTempFile(markdown)
            }
            .sheet(isPresented: $showShare) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
        }
    }

    private var largeFileCard: some View {
        VStack {
            Spacer()
            GlassCard {
                VStack(spacing: 16) {
                    ZStack {
                        Circle().fill(Theme.heroGradient).frame(width: 72, height: 72)
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    Text("Full export ready")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(Theme.textPrimary)
                    Text("This export is large (\(byteSize)). Preview is skipped so it stays fast — share the file or copy it straight to your assistant.")
                        .font(.subheadline)
                        .foregroundStyle(Theme.textSecondary)
                        .multilineTextAlignment(.center)

                    HStack(spacing: 18) {
                        if report.mode == .full {
                            statPill("\(report.rawSampleCount)", "raw samples")
                            statPill("\(report.rawSeries.count)", "metrics")
                        } else {
                            statPill("\(report.totalDataPoints)", "data points")
                            statPill("\(report.sectionsWithData.count)", "sections")
                        }
                        statPill(report.range.title, "window")
                    }
                    .padding(.top, 4)
                }
            }
            .padding(.horizontal, 20)
            Spacer()
            Spacer()
        }
    }

    private func statPill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.headline.weight(.bold))
                .foregroundStyle(Theme.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private var byteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(markdown.utf8.count), countStyle: .file)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                UIPasteboard.general.string = markdown
                withAnimation { copied = true }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    withAnimation { copied = false }
                }
            } label: {
                HStack {
                    Image(systemName: copied ? "checkmark" : "doc.on.doc")
                    Text(copied ? "Copied" : "Copy")
                }
                .font(.headline.weight(.semibold))
                .foregroundStyle(Theme.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Color.white.opacity(0.09))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Theme.cardStroke, lineWidth: 1)
                )
            }

            Button {
                showShare = true
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Share")
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
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

/// UIKit share sheet bridge.
struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
