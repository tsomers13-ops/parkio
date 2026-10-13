// OpenNowEligibilityTests.swift — regression for the "Rides Open Now" fix.
//
// Root cause of the real "21/60" defect: HomeView's and AttractionsListView's
// open-count denominators (and, on the All Attractions screen, numerator too)
// counted every seeded park entity regardless of category — rides, shows,
// character meets, AND every dining venue — instead of restricting to
// RideMasterData.typeByStableID[id] == .ride, the same rule the numerator in
// HomeView.rideableCandidates already used correctly.
//
// The count itself is simple glue inside private View internals (not
// reachable from a unit test without a view-inspection library this project
// doesn't have — see RecentlyViewedVisibilityUITests.swift for how the
// View-level behavior is regressed instead, via XCUITest). What IS directly
// testable, and is the actual source of truth the fix depends on, is the
// eligibility rule itself: which AttractionType values should count, and
// which RideStatus values should count as "open" — both tested here against
// real Magic Kingdom data already in RideMasterData.swift, not synthetic
// fixtures, so a future miscategorisation of real data would fail this test
// the same way the original bug would have.

import XCTest
@testable import Parkio

final class OpenNowEligibilityTests: XCTestCase {

    // MARK: - Real Magic Kingdom stableIDs, one per category

    // "Magic Kingdom|<land>|<name>" — matches MasterAttraction.stableID
    // exactly (see RideMasterData.swift's documented stableID contract).
    private let realRide          = "Magic Kingdom|Adventureland|Pirates of the Caribbean"
    private let realQuickService  = "Magic Kingdom|Main Street, U.S.A.|Main Street Bakery"
    private let realTableService  = "Magic Kingdom|Main Street, U.S.A.|Tony's Town Square Restaurant"
    private let realShow          = "Magic Kingdom|Liberty Square|Hall of Presidents"
    private let realCharacterMeet = "Magic Kingdom|Main Street, U.S.A.|Mickey Mouse at Town Square Theater"
    private let realTransport     = "Magic Kingdom|Main Street, U.S.A.|Walt Disney World Railroad"

    /// The exact eligibility rule the fix applies — restated here so the
    /// test documents the rule under test, not just its outcome. Mirrors
    /// HomeView.totalRideOnlyCount / AttractionsListView's openCount
    /// filter precisely: no `??` fallback, so an entity absent from
    /// typeByStableID is excluded, never defaulted to eligible.
    private func isEligibleForRideCount(_ stableID: String) -> Bool {
        RideMasterData.typeByStableID[stableID] == .ride
    }

    // MARK: - Category eligibility, against real data

    func testRealRideIsEligible() {
        XCTAssertEqual(RideMasterData.typeByStableID[realRide], .ride)
        XCTAssertTrue(isEligibleForRideCount(realRide))
    }

    func testRealQuickServiceDiningIsExcluded() {
        XCTAssertEqual(RideMasterData.typeByStableID[realQuickService], .quickService)
        XCTAssertTrue(RideMasterData.typeByStableID[realQuickService]?.isDining ?? false)
        XCTAssertFalse(isEligibleForRideCount(realQuickService))
    }

    func testRealTableServiceDiningIsExcluded() {
        XCTAssertEqual(RideMasterData.typeByStableID[realTableService], .tableService)
        XCTAssertTrue(RideMasterData.typeByStableID[realTableService]?.isDining ?? false)
        XCTAssertFalse(isEligibleForRideCount(realTableService))
    }

    func testRealShowIsExcluded() {
        XCTAssertEqual(RideMasterData.typeByStableID[realShow], .show)
        XCTAssertFalse(isEligibleForRideCount(realShow))
    }

    func testRealCharacterMeetIsExcluded() {
        XCTAssertEqual(RideMasterData.typeByStableID[realCharacterMeet], .characterMeet)
        XCTAssertFalse(isEligibleForRideCount(realCharacterMeet))
    }

    func testRealTransportIsExcluded() {
        // Transport (e.g. the WDW Railroad) is a real, seeded, non-dining
        // attraction that still must not count as a "ride" for this metric —
        // confirms the fix isn't accidentally "exclude dining only".
        XCTAssertEqual(RideMasterData.typeByStableID[realTransport], .transport)
        XCTAssertFalse(isEligibleForRideCount(realTransport))
    }

    func testUnknownStableIDIsExcludedNotDefaultedToRide() {
        // No "?? .ride" fallback anywhere in the fix — an entity this
        // repo has never heard of must never silently count.
        XCTAssertNil(RideMasterData.typeByStableID["Magic Kingdom|Nowhere|Not A Real Attraction"])
        XCTAssertFalse(isEligibleForRideCount("Magic Kingdom|Nowhere|Not A Real Attraction"))
    }

    // MARK: - Operating-status logic preserved exactly (task requirement: do not touch it)

    func testOperatingStatusIsRideable() {
        XCTAssertTrue(RideStatus.operating.isRideable)
    }

    func testDownStatusIsNotRideable() {
        XCTAssertFalse(RideStatus.down.isRideable)
    }

    func testClosedStatusIsNotRideable() {
        XCTAssertFalse(RideStatus.closed.isRideable)
    }

    func testRefurbishmentTemporarilyClosedStatusIsNotRideable() {
        XCTAssertFalse(RideStatus.refurbishment.isRideable)
    }

    func testUnknownStatusIsNotRideable() {
        XCTAssertFalse(RideStatus.unknown.isRideable)
    }

    // MARK: - The real defect, reproduced and guarded at the data level

    func testMagicKingdomHasFarFewerRealRidesThanTotalSeededEntities() {
        // Reproduces the exact shape of the reported "21/60": Magic Kingdom's
        // seeded entity count is dominated by dining, not rides. This guards
        // the underlying data (and therefore every view that consumes it)
        // against silently drifting back toward counting non-rides.
        let mkEntities = RideMasterData.all.filter { $0.park == .magicKingdom && $0.shouldSeed }
        let mkRideOnly = mkEntities.filter { isEligibleForRideCount($0.stableID) }

        XCTAssertGreaterThan(mkEntities.count, mkRideOnly.count * 2,
            "Expected total seeded Magic Kingdom entities to be more than double the real-ride count " +
            "(mirrors the reported 60 total vs. ~22 real rides) — if this no longer holds, re-verify " +
            "the fix still matters for this park.")
        XCTAssertGreaterThan(mkRideOnly.count, 0, "Expected at least some real Magic Kingdom rides")
    }

    func testRideOnlyFilterIsConsistentAcrossAllSupportedParks() {
        // Task requirement: consistent behavior across every supported park.
        // For every park, every entity the filter calls eligible must
        // actually be typed .ride, and the filter must never be vacuously
        // true (i.e. it must actually exclude something non-ride-eligible
        // somewhere, confirming the test fixtures above are representative
        // and not coincidentally all passing for an unrelated reason).
        for park in Park.allCases {
            let entities = RideMasterData.all.filter { $0.park == park && $0.shouldSeed }
            let eligible = entities.filter { isEligibleForRideCount($0.stableID) }
            for entity in eligible {
                XCTAssertEqual(
                    RideMasterData.typeByStableID[entity.stableID], .ride,
                    "\(park.rawValue): \(entity.name) was counted as ride-eligible but is not typed .ride"
                )
            }
            XCTAssertLessThan(
                eligible.count, entities.count,
                "\(park.rawValue): expected at least one non-ride entity (dining/show/etc.) to be excluded"
            )
        }
    }
}
