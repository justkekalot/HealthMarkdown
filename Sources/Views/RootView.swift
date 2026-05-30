import SwiftUI

struct RootView: View {
    @EnvironmentObject var health: HealthKitManager

    var body: some View {
        ZStack {
            AmbientBackground()

            switch health.authState {
            case .unknown, .requesting, .unavailable, .denied:
                OnboardingView()
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            case .authorized:
                MainTabView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: health.authState)
    }
}

/// Tab container. On iOS 26 the system tab bar adopts the Liquid Glass look
/// automatically; we keep the background transparent so the ambient gradient
/// shows through behind the glass.
struct MainTabView: View {
    @State private var selection = 0

    init() {
        // Let the ambient background show through the glass tab bar.
        let appearance = UITabBarAppearance()
        appearance.configureWithTransparentBackground()
        UITabBar.appearance().standardAppearance = appearance
        UITabBar.appearance().scrollEdgeAppearance = appearance
    }

    var body: some View {
        TabView(selection: $selection) {
            DashboardView()
                .tabItem {
                    Label("Export", systemImage: "sparkles")
                }
                .tag(0)

            HistoryView()
                .tabItem {
                    Label("History", systemImage: "clock.arrow.circlepath")
                }
                .tag(1)
        }
        .tint(Theme.accent)
    }
}
