import SwiftUI
import UIKit

/// First-launch walkthrough: welcome → shipping address → enable Siri.
/// Sets `store.hasOnboarded` when finished.
struct OnboardingView: View {
    @EnvironmentObject private var store: ProfileStore
    @Environment(\.openURL) private var openURL

    @State private var step: Step = .welcome
    @State private var draft = ShippingProfile()
    @State private var apiKeyDraft = ""
    @State private var settingsOpenFailed = false

    enum Step: Int, CaseIterable { case welcome, shipping, apiKey, siri }

    var body: some View {
        VStack(spacing: 0) {
            ProgressDots(count: Step.allCases.count, index: step.rawValue)
                .padding(.top, 24)

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                        removal: .move(edge: .leading).combined(with: .opacity)))

            footer
        }
        // One background for the whole flow (extending under the status bar) so
        // the progress-dots strip doesn't show as a white bar above the Form's
        // grouped-gray background.
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .animation(.snappy, value: step)
        .onAppear {
            // Restore a form the user started before backgrounding; otherwise
            // seed from any saved shipping profile.
            draft = store.onboardingDraft ?? store.shipping
            // Prefill with the effective key: the user's if set, otherwise the
            // bundled dev key from Secrets so it Just Works in development.
            apiKeyDraft = ZincCredentials.apiKey
        }
        // Persist each edit so a mid-onboarding interruption doesn't lose input.
        .onChange(of: draft) { _, newValue in store.onboardingDraft = newValue }
    }

    // MARK: Steps

    @ViewBuilder private var content: some View {
        switch step {
        case .welcome: welcomeStep
        case .shipping: shippingStep
        case .apiKey: apiKeyStep
        case .siri: siriStep
        }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "cart.fill.badge.plus")
                .font(.system(size: 72))
                .foregroundStyle(.tint)
            Text("Welcome to Zinc")
                .font(.largeTitle.bold())
            Text("Buy everyday essentials by voice.\nJust ask Siri.")
                .font(.title3)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PhraseCard()
            Spacer()
        }
        .padding()
    }

    private var shippingStep: some View {
        Form {
            Section {
                ShippingFields(profile: $draft)
            } header: {
                Text("Where should we ship?")
            } footer: {
                Text("Used for every order. You can change it later in Settings.")
            }
        }
    }

    private var apiKeyStep: some View {
        Form {
            Section {
                APIKeyField(text: $apiKeyDraft)
                APIKeyVerifyRow(key: apiKeyDraft)
            } header: {
                Text("Your Zinc API key")
            } footer: {
                Text("Used to search and place your orders. Get one at zinc.com. You can change or clear it later in Settings.")
            }
        }
    }

    private var siriStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "mic.badge.plus")
                        .font(.system(size: 56))
                        .foregroundStyle(.tint)
                    Text("Turn on Siri ordering")
                        .font(.title.bold())
                    Text("One-time step so Siri can run the Zinc shortcut.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(alignment: .leading, spacing: 14) {
                    InstructionRow(number: 1, text: "Open **Settings → Apps → Zinc → Siri** and turn it on. (Or Shortcuts app → search “Zinc”.)")
                    InstructionRow(number: 2, text: "Come back here and try a phrase below.")
                }

                Button {
                    guard let url = URL(string: UIApplication.openSettingsURLString) else {
                        settingsOpenFailed = true; return
                    }
                    openURL(url) { accepted in if !accepted { settingsOpenFailed = true } }
                } label: {
                    Label("Open Settings", systemImage: "gear")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .alert("Couldn't open Settings", isPresented: $settingsOpenFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Open the Settings app manually, then go to Apps → Zinc → Siri and turn it on.")
                }

                PhraseCard()
            }
            .padding()
        }
    }

    // MARK: Footer CTA

    @ViewBuilder private var footer: some View {
        VStack(spacing: 8) {
            Button(action: advance) {
                Text(ctaTitle).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(step == .shipping && !draft.isComplete)

            if step == .siri {
                Text("You can enable Siri later — everything also works by tapping in the app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding()
    }

    private var ctaTitle: String {
        switch step {
        case .welcome: "Get Started"
        case .shipping: "Continue"
        case .apiKey: "Continue"
        case .siri: "Start Shopping"
        }
    }

    private func advance() {
        switch step {
        case .welcome:
            step = .shipping
        case .shipping:
            store.shipping = draft
            step = .apiKey
        case .apiKey:
            // Only persist a key the user actually changed from the bundled dev
            // default; leaving the default untouched keeps the Keychain empty so
            // the resolver's dev fallback applies.
            store.zincApiKey = apiKeyDraft == ZincCredentials.apiKey ? store.zincApiKey
                                                                     : apiKeyDraft
            step = .siri
        case .siri:
            store.hasOnboarded = true
            store.onboardingDraft = nil   // setup done — drop the saved draft
        }
    }
}

// MARK: - Small pieces

private struct ProgressDots: View {
    let count: Int
    let index: Int
    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == index ? AnyShapeStyle(.tint) : AnyShapeStyle(.quaternary))
                    .frame(width: i == index ? 22 : 8, height: 8)
            }
        }
    }
}

private struct PhraseCard: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "waveform")
                .foregroundStyle(.tint)
            Text("“Hey Siri, order paper towels on Zinc”")
                .font(.callout.weight(.medium))
            Spacer(minLength: 0)
        }
        .padding()
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 14))
    }
}

private struct InstructionRow: View {
    let number: Int
    let text: LocalizedStringKey
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.bold())
                .foregroundStyle(.white)
                .frame(width: 26, height: 26)
                .background(.tint, in: Circle())
            Text(text)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }
}
