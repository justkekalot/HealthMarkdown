import SwiftUI

struct RootView: View {
    @EnvironmentObject var health: HealthKitManager
    @AppStorage("hasSeenIntro") private var hasSeenIntro = false

    var body: some View {
        ZStack {
            AmbientBackground()

            if !hasSeenIntro && health.authState != .authorized {
                IntroCarousel { withAnimation { hasSeenIntro = true } }
                    .transition(.opacity)
            } else {
                switch health.authState {
                case .unknown, .requesting, .unavailable, .denied:
                    OnboardingView()
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                case .authorized:
                    MainTabView()
                        .transition(.opacity)
                }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: health.authState)
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: hasSeenIntro)
    }
}

/// Tab container. On iOS 26 the system tab bar adopts the Liquid Glass look
/// automatically; we keep the background transparent so the ambient gradient
/// shows through behind the glass.
struct MainTabView: View {
    @EnvironmentObject var health: HealthKitManager
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
            RecoveryView()
                .tabItem {
                    Label("Readiness", image: "tab-readiness")
                }
                .tag(0)

            DashboardView()
                .tabItem {
                    Label("Health", systemImage: "heart.fill")
                }
                .tag(1)

            WorkoutsView()
                .tabItem {
                    Label("Workouts", systemImage: "figure.run")
                }
                .tag(2)

            HistoryView()
                .tabItem {
                    Label("History", image: "tab-history")
                }
                .tag(3)
        }
        .tint(Theme.accent)
        // Re-request read access on launch so metrics added since the user first
        // granted access get a permission prompt (otherwise they silently return
        // no data and their sections vanish from the export).
        .task { await health.ensureReadAccess() }
    }
}
