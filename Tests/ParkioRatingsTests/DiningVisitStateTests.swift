import XCTest
import SwiftData

@testable import Parkio

/// Regression coverage for the Pecos Bill header/card contradiction:
/// Ride.isRidden (the hero header, and now the Community Rating hook) and
/// DiningRecommendationSection's own label text (driven by DiningRatingStore)
/// could disagree because they read two different stores. These tests prove
/// the single authoritative visit path (Ride.logVisitIfNeeded) is idempotent,
/// identity-correct, and that the label-reconciliation helper used by the
/// view can never again say "Haven't tried this yet" once Ride.isRidden is
/// true — without touching DiningRecommendationService's own ranking/label
/// computation, which stays keyed purely on DiningRatingStore as before.
@MainActor
final class DiningVisitStateTests: XCTestCase {

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

        // The header (Ride.isRidden) and the reconciled card text must agree:
        // neither may say "never tried" while the other says "visited".
        XCTAssertTrue(ride.isRidden)
        let reconciled = recommendation.label.displayString(reconciledWithRideVisited: ride.isRidden)
        XCTAssertNotEqual(reconciled, "Haven't tried this yet",
                           "a manually-logged visit must never leave the card contradicting the header")
    }

    func testUnvisitedAndUnratedStillReadsAsNeverTried() {
        // The negative case: no rating, no visit of any kind — the original
        // copy is correct and must be preserved exactly.
        let label = DiningRecommendation.Label.neverTried
        XCTAssertEqual(label.displayString(reconciledWithRideVisited: false), "Haven't tried this yet")
    }

    func testRatedLabelsPassThroughReconciliationUnchanged() {
        // Reconciliation only ever touches the unrated case — every rated
        // label must be completely unaffected, in either visited state.
        for label: DiningRecommendation.Label in [.lovedLastTrip, .markedFavorite, .highlyRated(4), .previouslyRated(2), .wouldAvoid(1)] {
            XCTAssertEqual(label.displayString(reconciledWithRideVisited: false), label.displayString)
            XCTAssertEqual(label.displayString(reconciledWithRideVisited: true), label.displayString)
        }
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
