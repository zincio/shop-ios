import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var capDollars: Double = 50

    var body: some View {
        NavigationStack {
            Form {
                guardrailSection
                shippingSection
                apiKeySection
                siriSection
                developerSection
                onboardingSection
            }
            .navigationTitle("Settings")
            .onAppear { capDollars = Double(store.priceCapCents) / 100 }
            .onChange(of: capDollars) { _, new in store.priceCapCents = Int(new * 100) }
        }
    }

    private var guardrailSection: some View {
        Section("Spending guardrail") {
            Stepper(value: $capDollars, in: 5...500, step: 5) {
                LabeledContent("Per-order price cap") {
                    Text(capDollars.formatted(.currency(code: "USD")))
                        .font(.headline).foregroundStyle(.tint)
                        .contentTransition(.numericText())
                }
            }
            Text("Orders above this amount are blocked automatically.")
                .font(.caption).foregroundStyle(.secondary)
        }
    }

    private var shippingSection: some View {
        Section("Shipping") {
            NavigationLink("Edit shipping address") { ShippingSetupView() }
        }
    }

    private var apiKeySection: some View {
        Section {
            APIKeyField(text: $store.zincApiKey)
            APIKeyVerifyRow(key: store.zincApiKey)
        } header: {
            Text("Zinc API key")
        } footer: {
            Text(store.zincApiKey.isEmpty
                 ? "No key set — using the bundled development key. Add your own to place orders on your account."
                 : "Using your key. Clear the field to fall back to the bundled development key.")
        }
    }

    private var siriSection: some View {
        Section("Siri") {
            Text("Say “Hey Siri, order paper towels on Zinc.”")
                .font(.footnote).foregroundStyle(.secondary)
        }
    }

    private var developerSection: some View {
        Section {
            Toggle("Dev mode (max price $0)", isOn: $store.devMode)
        } header: {
            Text("Developer")
        } footer: {
            Text("Sends max_price = 0 on every order so nothing is actually purchased — safe for testing. Orders will report a price/finalization error.")
        }
    }

    private var onboardingSection: some View {
        Section {
            Button("Show setup guide again") { store.hasOnboarded = false }
        } footer: {
            Text("Replays the welcome, shipping, and enable-Siri walkthrough. Your saved address is kept.")
        }
    }
}
