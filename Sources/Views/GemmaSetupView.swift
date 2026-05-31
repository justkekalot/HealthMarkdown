import SwiftUI

/// Choose and download an on-device Gemma model for richer answers.
struct GemmaSetupView: View {
    @EnvironmentObject var gemma: GemmaModelManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        if gemma.isReady { readyCard } else { variantPicker; statusArea }
                        privacyNote
                    }
                    .padding(20)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("On-device AI")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
            }
        }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Run Gemma on your phone")
                .font(.system(size: 26, weight: .bold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
            Text("Download Google's Gemma model to get freeform, conversational answers about your readiness — fully offline, nothing leaves your device. The built-in engine keeps working without it.")
                .font(.subheadline).foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 8)
    }

    private var variantPicker: some View {
        VStack(spacing: 10) {
            ForEach(GemmaModelManager.Variant.allCases) { v in
                let selected = gemma.selectedVariant == v
                Button { gemma.selectedVariant = v; gemma.refreshState() } label: {
                    HStack(spacing: 12) {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .foregroundStyle(selected ? Theme.accent : Theme.textSecondary)
                        VStack(alignment: .leading, spacing: 2) {
                            HStack {
                                Text(v.title).font(.body.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                                Text(v.sizeText).font(.caption).foregroundStyle(Theme.accent)
                            }
                            Text(v.blurb).font(.footnote).foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                    }
                    .padding(14)
                    .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(selected ? Theme.subtleGradient : LinearGradient(colors: [Theme.control], startPoint: .top, endPoint: .bottom)))
                    .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(selected ? Theme.accent.opacity(0.5) : Theme.cardStroke, lineWidth: 1))
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var statusArea: some View {
        switch gemma.state {
        case .downloading(let p):
            GlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        ProgressView().tint(Theme.accent)
                        Text("Downloading \(gemma.selectedVariant.title)… \(Int(p*100))%")
                            .font(.subheadline).foregroundStyle(Theme.textPrimary)
                        Spacer()
                    }
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Theme.control)
                            Capsule().fill(Theme.accent).frame(width: max(6, geo.size.width * p))
                        }
                    }.frame(height: 6)
                    Button("Cancel") { gemma.cancel() }.font(.subheadline).foregroundStyle(Theme.accent)
                }
            }
        case .failed(let msg):
            VStack(spacing: 12) {
                Text(msg).font(.footnote).foregroundStyle(Theme.textSecondary).fixedSize(horizontal: false, vertical: true)
                downloadButton
            }
        default:
            downloadButton
        }
    }

    private var downloadButton: some View {
        Button { gemma.download() } label: {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                Text("Download \(gemma.selectedVariant.title) · \(gemma.selectedVariant.sizeText)")
            }
        }
        .buttonStyle(PrimaryButtonStyle())
    }

    private var readyCard: some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    Image(systemName: "checkmark.seal.fill").font(.title2).foregroundStyle(Theme.mint)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(gemma.selectedVariant.title) ready").font(.headline).foregroundStyle(Theme.textPrimary)
                        Text("Answers now run through Gemma, on-device.").font(.footnote).foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                Button(role: .destructive) { gemma.delete() } label: {
                    Text("Remove model (free up \(gemma.selectedVariant.sizeText))")
                        .font(.subheadline).foregroundStyle(Theme.accent)
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(spacing: 8) {
            Image(systemName: "lock.fill").font(.caption)
            Text("The model runs entirely offline once downloaded. Your health data and questions never leave the device.")
                .font(.caption).fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.textSecondary).padding(.top, 4)
    }
}
