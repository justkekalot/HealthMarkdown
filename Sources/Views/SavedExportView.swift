import SwiftUI
import UIKit

/// Read-only viewer for an export already saved on disk (opened from History).
struct SavedExportView: View {
    let record: ExportRecord
    @EnvironmentObject var exports: ExportStore
    @Environment(\.dismiss) private var dismiss
    @State private var markdown = ""
    @State private var loading = true
    @State private var copied = false
    @State private var showShare = false

    /// Mirror PreviewView: above this size, skip rendering the raw text.
    private var isLarge: Bool { markdown.utf8.count > 60_000 }

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

                if loading {
                    ProgressView().tint(Theme.accent)
                } else if isLarge {
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
                                    .fill(Theme.surfaceSunken)
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

                VStack { Spacer(); actionBar }
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
                // Read the (possibly large) file off the main thread.
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
        }
    }

    private var largeFileCard: some View {
        GlassCard {
            VStack(spacing: 16) {
                ZStack {
                    Circle().fill(Theme.heroGradient).frame(width: 72, height: 72)
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 32, weight: .semibold))
                        .foregroundStyle(.white)
                }
                Text("Large export")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.textPrimary)
                Text("This file is \(byteSize). Preview is skipped to keep it fast — share the file straight to your assistant.")
                    .font(.subheadline)
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 20)
    }

    private var byteSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(markdown.utf8.count), countStyle: .file)
    }

    private var actionBar: some View {
        HStack(spacing: 12) {
            if !isLarge {
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
                            .fill(Theme.controlStrong)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Theme.cardStroke, lineWidth: 1)
                    )
                }
            }

            Button { showShare = true } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text(isLarge ? "Share file" : "Share")
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
}
