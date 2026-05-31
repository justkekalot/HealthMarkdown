import SwiftUI

/// One-time unlock paywall. Pay once → all exports forever, no subscription.
struct PaywallView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ZStack {
                AmbientBackground()

                ScrollView {
                    VStack(alignment: .leading, spacing: 26) {
                        header

                        VStack(alignment: .leading, spacing: 4) {
                            benefit("infinity", "Unlimited exports", "Quick and Full, any time window — forever.")
                            Divider().overlay(Theme.cardStroke)
                            benefit("checkmark.seal.fill", "One-time purchase", "Pay once. No subscription, no recurring charge.")
                            Divider().overlay(Theme.cardStroke)
                            benefit("lock.fill", "Stays private", "Everything is still read on-device and never uploaded.")
                        }
                        .padding(.top, 8)

                        Spacer(minLength: 12)
                    }
                    .padding(24)
                }
                .scrollIndicators(.hidden)

                VStack { Spacer(); purchaseBar }
            }
            .navigationTitle("Unlock everything")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Not now") { dismiss() }.foregroundStyle(Theme.textPrimary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Restore") { Task { await purchases.restore() } }
                        .foregroundStyle(Theme.accent)
                }
            }
            .onChange(of: purchases.isUnlocked) { _, unlocked in
                if unlocked { dismiss() }
            }
            .alert("Store", isPresented: Binding(
                get: { purchases.lastError != nil },
                set: { if !$0 { purchases.lastError = nil } }
            )) {
                Button("OK", role: .cancel) { purchases.lastError = nil }
            } message: {
                Text(purchases.lastError ?? "")
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Theme.heroGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.accent.opacity(0.3), radius: 12, x: 0, y: 6)
                Image(systemName: "sparkles")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
            }
            Text("Unlock the full export.")
                .font(.system(size: 30, weight: .bold, design: .serif))
                .foregroundStyle(Theme.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Quick · 24 hours is always free. Unlock once for every period and the full raw export — forever.")
                .font(.body)
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.top, 12)
    }

    private func benefit(_ icon: String, _ title: String, _ subtitle: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(Theme.accent)
                .frame(width: 30)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.subheadline.weight(.semibold)).foregroundStyle(Theme.textPrimary)
                Text(subtitle).font(.footnote).foregroundStyle(Theme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private var purchaseBar: some View {
        VStack(spacing: 10) {
            Button {
                Task { await purchases.purchase() }
            } label: {
                HStack {
                    if purchases.purchaseInFlight {
                        ProgressView().tint(.white)
                    } else {
                        Text(purchases.priceText.map { "Unlock forever · \($0)" } ?? "Unlock forever")
                    }
                }
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(purchases.purchaseInFlight)

            Text("One-time payment · no subscription")
                .font(.footnote)
                .foregroundStyle(Theme.textSecondary)
        }
        .padding(16)
        .background(
            LinearGradient(colors: [Theme.bg.opacity(0), Theme.bg], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
        )
    }
}
