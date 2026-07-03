import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ProfileStore
    /// Drives the purchase sheet. Kept separate from `store.pendingPurchase` and
    /// populated after the view appears so the sheet reliably presents even when
    /// a pending purchase already exists at launch (a Siri-initiated buy that
    /// relaunches the app). `.sheet(isPresented:)` with an already-true value at
    /// first render often fails to present.
    @State private var activePurchase: PendingPurchase?

    var body: some View {
        Group {
            if store.shipping.isComplete {
                TabView {
                    HomeView()
                        .tabItem { Label("Shop", systemImage: "cart") }
                    OrderListView()
                        .tabItem { Label("Orders", systemImage: "shippingbox") }
                    SettingsView()
                        .tabItem { Label("Settings", systemImage: "gearshape") }
                }
            } else {
                ShippingSetupView()
            }
        }
        // A purchase initiated by Siri lands here: present Apple Pay to finish it.
        .sheet(item: $activePurchase, onDismiss: { store.pendingPurchase = nil }) { pending in
            PurchaseFlowView(product: pending.product, quantity: pending.quantity)
                .environmentObject(store)
        }
        .task { syncPendingPurchase() }
        .onChange(of: store.pendingPurchase) { _, _ in syncPendingPurchase() }
    }

    private func syncPendingPurchase() {
        if let pending = store.pendingPurchase, activePurchase == nil {
            activePurchase = pending
        }
    }
}
