import SwiftUI

struct RootView: View {
    @EnvironmentObject private var store: ProfileStore

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
        .sheet(isPresented: pendingBinding) {
            if let pending = store.pendingPurchase {
                PurchaseFlowView(product: pending.product, quantity: pending.quantity)
            }
        }
    }

    private var pendingBinding: Binding<Bool> {
        Binding(
            get: { store.pendingPurchase != nil },
            set: { if !$0 { store.pendingPurchase = nil } }
        )
    }
}
