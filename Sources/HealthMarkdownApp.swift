import SwiftUI

@main
struct HealthMarkdownApp: App {
    @StateObject private var health = HealthKitManager()
    @StateObject private var exports = ExportStore()
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var gemma = GemmaModelManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(health)
                .environmentObject(exports)
                .environmentObject(purchases)
                .environmentObject(gemma)
        }
    }
}
