import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.scenePhase) private var scenePhase
    /// Drives the purchase sheet. Kept separate from `store.pendingPurchase` and
    /// populated after the view appears so the sheet reliably presents even when
    /// a pending purchase already exists at launch (a Siri-initiated buy that
    /// relaunches the app). `.sheet(isPresented:)` with an already-true value at
    /// first render often fails to present.
    @State private var activePurchase: PendingPurchase?
    /// Which tab is showing. Bound so a Siri search (`SearchProductsIntent`) can
    /// bring the Shop tab forward before `HomeView` runs the query.
    @State private var selectedTab: Tab = .shop

    enum Tab: Hashable { case shop, orders, settings }

    var body: some View {
        Group {
            if store.hasOnboarded {
                TabView(selection: $selectedTab) {
                    HomeView()
                        .tabItem { Label("Shop", systemImage: "cart") }
                        .tag(Tab.shop)
                    OrderListView()
                        .tabItem { Label("Orders", systemImage: "shippingbox") }
                        .tag(Tab.orders)
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                        .tag(Tab.settings)
                }
            } else {
                OnboardingView()
            }
        }
        // A purchase initiated by Siri lands here: present Apple Pay to finish it.
        .sheet(item: $activePurchase, onDismiss: { store.pendingPurchase = nil }) { pending in
            PurchaseFlowView(product: pending.product, quantity: pending.quantity)
                .environmentObject(store)
        }
        .task {
            syncPendingPurchase()
            focusShopForPendingSearch()
            await refreshLiveActivities()
        }
        .onChange(of: scenePhase) { _, phase in
            // Re-adopt/refresh activities and restart any dead pollers whenever
            // the app returns to the foreground (.task covers cold launch).
            if phase == .active { Task { await refreshLiveActivities() } }
        }
        .onChange(of: store.pendingPurchase) { _, _ in syncPendingPurchase() }
        .onChange(of: store.pendingSearch) { _, _ in focusShopForPendingSearch() }
    }

    private func refreshLiveActivities() async {
        await LiveActivityManager.reattach(to: store.orders)
        OrderTracker.shared.resumeAll()
    }

    private func focusShopForPendingSearch() {
        // Bring the Shop tab forward so HomeView can consume the query; HomeView
        // clears `pendingSearch` once it runs the search.
        if store.pendingSearch != nil { selectedTab = .shop }
    }

    private func syncPendingPurchase() {
        // Don't surface a purchase over the first-run onboarding.
        guard store.hasOnboarded else { return }
        if let pending = store.pendingPurchase, activePurchase == nil {
            activePurchase = pending
        }
    }
}
