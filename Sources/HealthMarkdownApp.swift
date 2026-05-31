import SwiftUI

@main
struct HealthMarkdownApp: App {
    @StateObject private var health = HealthKitManager()
    @StateObject private var exports = ExportStore()
    @StateObject private var purchases = PurchaseManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environmentObject(exports)
                .environmentObject(purchases)
        }
    }
}
