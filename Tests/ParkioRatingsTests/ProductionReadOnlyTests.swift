import XCTest

/// Read-only checks against the live Production backend.
///
/// Skipped unless PARKIO_PRODUCTION_CHECK=1. Deliberately contains no write
/// path at all — there is no submit here, so it cannot create a synthetic
/// Production rating even by mistake.
@MainActor
final class ProductionReadOnlyTests: XCTestCase {

    private func settle() async {
        for _ in 0..<40 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    func testEligibleVenueReadsCleanlyAndCreatesNoIdentity() async throws {
        guard ProcessInfo.processInfo.environment["PARKIO_PRODUCTION_CHECK"] == "1" else {
            throw XCTSkip("PARKIO_PRODUCTION_CHECK not set")
        }
        // Uses the app's own Release-facing host, not an override.
        let store = InMemoryRatingCredentialStore()
        let vm = CommunityRatingViewModel(
            venueKey: "ep-le-cellier",
            service: CommunityRatingService(
                transport: URLSession.shared,
                credentials: store,
                baseURL: ParkioAPI.productionBaseURL
            )
        )

        vm.loadIfNeeded()
        await settle()

        // Production has no ratings yet, so the honest state is zero — not
        // unavailable, and certainly not a fabricated 0.0.
        XCTAssertEqual(vm.load, .zero)
        XCTAssertTrue(vm.visibleDimensions.isEmpty)
        XCTAssertFalse(vm.hasPersonalRating)

        // Browsing must leave the guest anonymous.
        XCTAssertNil(try store.load(), "reading Production must not mint a credential")
    }

    func testIneligibleVenueHasNoRatingIdentityAtAll() throws {
        guard ProcessInfo.processInfo.environment["PARKIO_PRODUCTION_CHECK"] == "1" else {
            throw XCTSkip("PARKIO_PRODUCTION_CHECK not set")
        }
        // nil is what stops the detail screen building the section, so this is
        // the guarantee that an ineligible venue makes no request at all.
        for stableID in [
            "Magic Kingdom|Liberty Square|Columbia Harbour House",
            "Animal Kingdom|Discovery Island|Flame Tree Barbecue",
        ] {
            XCTAssertNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }
}
