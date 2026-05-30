import SwiftUI

@main
struct HealthMarkdownApp: App {
    @StateObject private var health = HealthKitManager()
    @StateObject private var exports = ExportStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environmentObject(exports)
        }
    }
}
