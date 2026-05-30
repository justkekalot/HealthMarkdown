import SwiftUI
import UIKit

/// Read-only viewer for an export already saved on disk (opened from History).
struct SavedExportView: View {
    let record: ExportRecord
    @EnvironmentObject var exports: ExportStore
    @Environment(\.dismiss) private var dismiss
    @State private var markdown = ""
    @State private var copied = false
    @State private var showShare = false

    var body: some View {
        NavigationStack {
            ZStack {
                Theme.bg.ignoresSafeArea()

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
            .onAppear { markdown = exports.markdown(for: record) }
            .sheet(isPresented: $showShare) {
                ShareSheet(items: [exports.fileURL(for: record)])
            }
        }
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

            Button { showShare = true } label: {
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
}
