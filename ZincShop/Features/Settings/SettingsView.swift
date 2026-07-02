import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var capDollars: Double = 50

    var body: some View {
        NavigationStack {
            Form {
                Section("Spending guardrail") {
                    Stepper(value: $capDollars, in: 5...500, step: 5) {
                        LabeledContent("Per-order price cap",
                                       value: capDollars.formatted(.currency(code: "USD")))
                    }
                    Text("Orders above this amount are blocked automatically.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Shipping") {
                    NavigationLink("Edit shipping address") { ShippingSetupView() }
                }
                Section("Siri") {
                    Text("Say “Hey Siri, buy toilet paper with Zinc.”")
                        .font(.footnote).foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Settings")
            .onAppear { capDollars = Double(store.priceCapCents) / 100 }
            .onChange(of: capDollars) { _, new in store.priceCapCents = Int(new * 100) }
        }
    }
}
