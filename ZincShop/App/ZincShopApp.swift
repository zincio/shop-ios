import SwiftUI
import AppIntents

@main
struct ZincShopApp: App {
    @StateObject private var store = ProfileStore.shared

    init() {
        // Nudge the system to (re)register our App Shortcuts with Siri on
        // launch — avoids stale-index states where Shortcuts can't find the
        // AppShortcutsProvider after reinstalls.
        ZincShopShortcuts.updateAppShortcutParameters()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
        }
    }
}
