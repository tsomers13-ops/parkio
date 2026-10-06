import XCTest
import SwiftData

@testable import Parkio

/// Regression coverage for the Pecos Bill header/card contradiction, and the
/// follow-up Pinocchio Village Haus semantic fix:
/// Ride.isRidden (the hero header, and now the Community Rating hook) and
/// DiningRecommendationSection's own label text (driven by DiningRatingStore)
/// could disagree because they read two different stores. These tests prove
/// the single authoritative visit path (Ride.logVisitIfNeeded) is idempotent,
/// identity-correct, and that the label-reconciliation helper used by the
/// view reads exactly "Visited" — never "Haven't tried this yet" and never
/// any "not yet rated" claim — once Ride.isRidden is true, regardless of
/// whether a Community Rating exists (this type has no visibility into that
/// system either way). None of this touches DiningRecommendationService's
/// own ranking/label computation, which stays keyed purely on
/// DiningRatingStore as before.
@MainActor
final class DiningVisitStateTests: XCTestCase {

    /// DiningRatingStore persists to the real UserDefaults.standard (no test
    /// seam), which survives between separate `xcodebuild test` invocations
    /// on the same simulator. Clearing its key before every test guarantees
    /// a hermetic DiningRatingStore() regardless of what any earlier run —
    /// in this file or otherwise — left behind.
    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: "parkio_diningRatings_v1")
    }

    private func makeContext() throws -> ModelContext {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Ride.self, RideLog.self, configurations: config)
        return ModelContext(container)
    }

    private func makeRide(id: String, name: String, park: String, land: String, in context: ModelContext) -> Ride {
        let ride = Ride(id: id, name: name, park: park, land: land, order: 0)
        context.insert(ride)
        return ride
    }

    // MARK: - logVisitIfNeeded idempotency (regression tests 1-3)

    func testLogVisitIfNeededCreatesExactlyOneVisitWhenNoneExists() throws {
        let context = try makeContext()
        let ride = makeRide(id: "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe",
                             name: "Pecos Bill Tall Tale Inn and Cafe", park: "Magic Kingdom",
                             land: "Frontierland", in: context)
        XCTAssertFalse(ride.isRidden)
        XCTAssertEqual(ride.rideCount, 0)

        ride.logVisitIfNeeded(in: context)

        XCTAssertTrue(ride.isRidden)
        XCTAssertEqual(ride.rideCount, 1, "first Community Rating on an unvisited venue must create exactly one visit")
    }

    func testLogVisitIfNeededNeverIncrementsAnExistingVisit() throws {
        let context = try makeContext()
        let ride = makeRide(id: "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe",
                             name: "Pecos Bill Tall Tale Inn and Cafe", park: "Magic Kingdom",
                             land: "Frontierland", in: context)
        let firstVisit = RideLog(date: Date(), ride: ride)
        context.insert(firstVisit)
        ride.logs.append(firstVisit)
        XCTAssertEqual(ride.rideCount, 1)

        // Simulates: a second Community Rating submission (an update), and —
        // separately — a first Community Rating on a venue already visited
        // by some other means. Neither must add a visit.
        ride.logVisitIfNeeded(in: context)
        ride.logVisitIfNeeded(in: context)
        ride.logVisitIfNeeded(in: context)

        XCTAssertEqual(ride.rideCount, 1, "an update (or a first rating on an already-visited venue) must not inflate the visit count")
    }

    // MARK: - Manual visit agreement (regression test 5)

    func testManualVisitAndReconciledLabelAgree() throws {
        let context = try makeContext()
        let ride = makeRide(id: "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe",
                             name: "Pecos Bill Tall Tale Inn and Cafe", park: "Magic Kingdom",
                             land: "Frontierland", in: context)
        // Simulates the "Log a visit" date picker / "Mark as visited" toggle —
        // neither of which ever touches DiningRatingStore.
        let manualLog = RideLog(date: Date(), ride: ride)
        context.insert(manualLog)
        ride.logs.append(manualLog)

        let store = DiningRatingStore()
        let venue = MasterAttraction(ride.name, park: .magicKingdom, land: ride.land, type: .quickService, seed: true)
        let recommendation = DiningRecommendationService.recommend(venue: venue, store: store)

        // DiningRecommendationService itself is unchanged: with no DiningRating,
        // the label is still .neverTried / isUnvisited — this is a RATING fact,
        // not a visited fact, and the guardrail says this must not change.
        XCTAssertTrue(recommendation.label.isUnvisited)

        // The header (Ride.isRidden) and the reconciled card text must agree,
        // and the reconciled text must say only "Visited" — never "never
        // tried" and never any "not yet rated" claim, since a Community
        // Rating this type has no visibility into may exist (CASE 2).
        XCTAssertTrue(ride.isRidden)
        let reconciled = recommendation.label.displayString(reconciledWithRideVisited: ride.isRidden)
        XCTAssertEqual(reconciled, "Visited",
                        "a visited, privately-unrated venue must read exactly 'Visited' — no 'never tried', no 'not yet rated'")
    }

    func testVisitedWithNoPrivateRatingReadsAsVisitedRegardlessOfCommunityRating() throws {
        // CASE 3: the venue has a Community Rating (server-side, a different
        // system entirely) but still no private DiningRating. This type has
        // zero visibility into Community Ratings, so the reconciled text must
        // be identical to the plain "visited, unrated" case — proving the
        // card never implies "not rated anywhere in Parkio".
        let context = try makeContext()
        let ride = makeRide(id: "Magic Kingdom|Fantasyland|Pinocchio Village Haus",
                             name: "Pinocchio Village Haus", park: "Magic Kingdom",
                             land: "Fantasyland", in: context)
        ride.logVisitIfNeeded(in: context)

        let store = DiningRatingStore()
        let venue = MasterAttraction(ride.name, park: .magicKingdom, land: ride.land, type: .quickService, seed: true)
        let recommendation = DiningRecommendationService.recommend(venue: venue, store: store)

        let reconciled = recommendation.label.displayString(reconciledWithRideVisited: ride.isRidden)
        XCTAssertEqual(reconciled, "Visited")
        XCTAssertFalse(reconciled.contains("rated"), "the visit card must never make any rating claim")
    }

    func testUnvisitedAndUnratedStillReadsAsNeverTried() {
        // CASE 1 — the negative case: no rating, no visit of any kind. The
        // original copy is correct and must be preserved exactly.
        let label = DiningRecommendation.Label.neverTried
        XCTAssertEqual(label.displayString(reconciledWithRideVisited: false), "Haven't tried this yet")
    }

    func testRatedLabelsPassThroughReconciliationUnchanged() {
        // CASE 4 — reconciliation only ever touches the unrated case; every
        // rated label must be completely unaffected, in either visited state.
        for label: DiningRecommendation.Label in [.lovedLastTrip, .markedFavorite, .highlyRated(4), .previouslyRated(2), .wouldAvoid(1)] {
            XCTAssertEqual(label.displayString(reconciledWithRideVisited: false), label.displayString)
            XCTAssertEqual(label.displayString(reconciledWithRideVisited: true), label.displayString)
        }
    }

    func testExistingPrivateRatingPresentationIsUnaffected() throws {
        // CASE 4, end to end: once a private DiningRating exists, the
        // reconciled card must show the SAME rated label it always has —
        // the visit-fact override must never fire when a private rating
        // is present, regardless of Ride.isRidden.
        //
        // DiningRatingStore persists to real UserDefaults.standard (no test
        // seam), so this uses a venue name no other test in this file (or
        // elsewhere) saves a rating under, and cleans up after itself to
        // leave no residue for later runs. Ride.id, the DiningRating's
        // attractionID, and venue.stableID must all agree — that is exactly
        // the identity contract under test.
        let name = "DiningVisitStateTests-Only Venue"
        let land = "Frontierland"
        let stableID = "Magic Kingdom|\(land)|\(name)"
        let context = try makeContext()
        let ride = makeRide(id: stableID, name: name, park: "Magic Kingdom", land: land, in: context)
        ride.logVisitIfNeeded(in: context)

        let store = DiningRatingStore()
        defer { store.delete(attractionID: stableID) }
        store.save(DiningRating(attractionID: stableID, rating: 5, lastVisited: ride.mostRecentDate))
        let venue = MasterAttraction(name, park: .magicKingdom, land: land, type: .quickService, seed: true)
        XCTAssertEqual(venue.stableID, stableID, "test setup sanity check — venue lookup key must match the saved rating's key")
        let recommendation = DiningRecommendationService.recommend(venue: venue, store: store)

        XCTAssertEqual(recommendation.label.displayString(reconciledWithRideVisited: ride.isRidden), "Loved this last trip")
    }

    // MARK: - Persistence across reopening the detail view (regression test 6)

    func testVisitPersistsAcrossReloadingTheRideFromContext() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: Ride.self, RideLog.self, configurations: config)
        let writeContext = ModelContext(container)

        let id = "Magic Kingdom|Frontierland|Pecos Bill Tall Tale Inn and Cafe"
        let ride = Ride(id: id, name: "Pecos Bill Tall Tale Inn and Cafe", park: "Magic Kingdom", land: "Frontierland", order: 0)
        writeContext.insert(ride)
        ride.logVisitIfNeeded(in: writeContext)
        try writeContext.save()

        // A fresh context against the same container — simulates dismissing
        // and reopening the detail sheet, which re-fetches the Ride.
        let readContext = ModelContext(container)
        let fetched = try readContext.fetch(FetchDescriptor<Ride>(predicate: #Predicate { $0.id == id }))
        guard let reopened = fetched.first else { return XCTFail("ride not persisted") }

        XCTAssertTrue(reopened.isRidden)
        XCTAssertEqual(reopened.rideCount, 1)
    }

    // MARK: - Identity (regression test 7)

    func testVisitIdentityUsesStableIDNotDisplayName() throws {
        let context = try makeContext()
        // Two different physical venues that happen to share a display name —
        // only their stableID (Park|Land|Name) distinguishes them.
        let epcotVenue = makeRide(id: "EPCOT|World Showcase|Refreshment Port",
                                   name: "Refreshment Port", park: "EPCOT", land: "World Showcase", in: context)
        let otherVenue = makeRide(id: "Magic Kingdom|Tomorrowland|Refreshment Port",
                                   name: "Refreshment Port", park: "Magic Kingdom", land: "Tomorrowland", in: context)

        epcotVenue.logVisitIfNeeded(in: context)

        XCTAssertTrue(epcotVenue.isRidden)
        XCTAssertFalse(otherVenue.isRidden, "visiting one venue must never mark a same-named venue at a different stableID as visited")
    }
}
