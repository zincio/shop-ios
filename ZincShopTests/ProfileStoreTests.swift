import XCTest
@testable import ZincShop

@MainActor
final class ProfileStoreTests: XCTestCase {
    private let suite = "ProfileStoreTests.onboardingDraft"

    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func testOnboardingDraftPersistsAcrossLoads() {
        let defaults = freshDefaults()
        XCTAssertNil(ProfileStore(defaults: defaults).onboardingDraft)

        let store = ProfileStore(defaults: defaults)
        var draft = ShippingProfile()
        draft.firstName = "Ada"
        draft.city = "London"
        store.onboardingDraft = draft

        // A fresh store reading the same defaults restores the in-progress form.
        let reloaded = ProfileStore(defaults: defaults)
        XCTAssertEqual(reloaded.onboardingDraft?.firstName, "Ada")
        XCTAssertEqual(reloaded.onboardingDraft?.city, "London")

        defaults.removePersistentDomain(forName: suite)
    }

    func testClearingOnboardingDraftRemovesIt() {
        let defaults = freshDefaults()
        let store = ProfileStore(defaults: defaults)
        store.onboardingDraft = ShippingProfile()
        XCTAssertNotNil(ProfileStore(defaults: defaults).onboardingDraft)

        store.onboardingDraft = nil
        XCTAssertNil(ProfileStore(defaults: defaults).onboardingDraft)

        defaults.removePersistentDomain(forName: suite)
    }
}
