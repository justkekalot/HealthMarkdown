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
                DashboardView()
                    .transition(.opacity)
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: health.authState)
    }
}
