import XCTest

@testable import Parkio

/// The boundaries between the three concepts a dining venue can now carry:
/// the Community rating (server), the Parkio editorial score (content), and
/// the private journal (device-only).
final class CommunityIsolationTests: XCTestCase {

    // MARK: - Nothing private ever leaves the device

    func testSubmissionCarriesOnlyTheFourDimensions() throws {
        let submission = DiningRatingSubmission(overall: 4, taste: 5, value: 3, quality: 2)
        let json = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(submission)
        ) as! [String: Any]

        XCTAssertEqual(Set(json.keys), ["overall", "taste", "value", "quality"])
    }

    func testSubmissionCannotCarryPrivateJournalFields() throws {
        let raw = String(
            data: try JSONEncoder().encode(DiningRatingSubmission(overall: 5)),
            encoding: .utf8
        )!
        // The private journal's fields have no representation in the wire type,
        // so this is belt-and-braces against someone adding one later.
        for forbidden in ["notes", "isFavorite", "favourite", "lastVisited", "attractionID", "dateRated"] {
            XCTAssertFalse(raw.contains(forbidden), "'\(forbidden)' must never be uploaded")
        }
    }

    func testCommunityRatingIsKeyedByVenueKeyNotStableID() {
        // A stableID must never be accepted as a rating identity: the two
        // namespaces are different and the backend would 404.
        let stableID = "EPCOT|World Showcase|Le Cellier Steakhouse"
        XCTAssertEqual(DiningVenueKeys.venueKey(forStableID: stableID), "ep-le-cellier")
        XCTAssertNil(DiningVenueKeys.venueKey(forStableID: "ep-le-cellier"))
    }

    // MARK: - Eligibility

    func testExactlyTheCurrentPilotIsEligible() {
        XCTAssertEqual(DiningVenueKeys.byStableID.count, 193)
    }

    func testUnsupportedIdentitiesResolveToNoVenueKey() {
        // Synthetic unsupported identities — no real Dining park in Parkio
        // is modeled but Community-Ratings-ineligible anymore (all six are
        // eligible), so there is no real "ineligible park" fixture to use
        // here; these exercise the generic unknown-identity path instead.
        let unsupported = [
            "Unsupported Park|Unknown Land|Unknown Venue",
            "EPCOT|Nowhere|Nowhere",
        ]
        for stableID in unsupported {
            XCTAssertNil(
                DiningVenueKeys.venueKey(forStableID: stableID),
                "\(stableID) must not be rateable"
            )
            XCTAssertFalse(DiningVenueKeys.isRateable(stableID: stableID))
        }
    }

    func testUnsupportedVenueYieldsNoServiceIdentityAtAll() {
        // The detail screen builds the Community section only when this is
        // non-nil, so nil is what guarantees no UI and no network call.
        XCTAssertNil(CommunityRatingService.venueKey(forStableID: "Unsupported Park|Unknown Land|Unknown Venue"))
    }

    func testEligibleVenueYieldsAVenueKey() {
        XCTAssertEqual(
            CommunityRatingService.venueKey(forStableID: "Hollywood Studios|Echo Lake|Backlot Express"),
            "hs-backlot-express"
        )
    }

    // MARK: - Editorial stays separate

    func testCommunityAggregateCarriesNoEditorialScore() throws {
        let json = """
        {"venueKey":"ep-le-cellier","ratingCount":4,"overallAverage":4.5,
         "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
         "qualityAverage":null,"qualityCount":0}
        """
        let aggregate = try JSONDecoder().decode(
            CommunityRatingAggregate.self, from: Data(json.utf8)
        )
        // Community is /5 and knows nothing about Parkio's /10 editorial score.
        XCTAssertEqual(aggregate.overallAverage, 4.5)
        XCTAssertTrue(aggregate.overallAverage! <= 5)
    }
}
