import SwiftUI

@main
struct ZincShopApp: App {
    @StateObject private var store = ProfileStore.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
