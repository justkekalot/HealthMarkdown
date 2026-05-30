import SwiftUI

@main
struct HealthMarkdownApp: App {
    @StateObject private var health = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .preferredColorScheme(.dark)
        }
    }
}
