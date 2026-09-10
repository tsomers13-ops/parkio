import XCTest

/// The website runs `trailingSlash: true`. Without the slash Next answers 308
/// and URLSession replays the redirect as a GET, silently dropping a POST body.
final class EndpointTests: XCTestCase {

    func testRatingsPathHasATrailingSlash() {
        XCTAssertEqual(ParkioAPI.ratingsPath(venueKey: "ep-le-cellier"), "/api/dining/ep-le-cellier/ratings/")
    }

    func testMyRatingPathHasATrailingSlash() {
        XCTAssertEqual(ParkioAPI.myRatingPath(venueKey: "ep-le-cellier"), "/api/dining/ep-le-cellier/ratings/me/")
    }

    func testBulkPathHasATrailingSlashBeforeTheQuery() {
        let path = ParkioAPI.bulkRatingsPath(venueKeys: ["ep-a", "hs-b"])
        XCTAssertEqual(path, "/api/dining/ratings/?venueKeys=ep-a,hs-b")
        XCTAssertTrue(path.hasPrefix("/api/dining/ratings/?"))
    }

    func testIdentityPathHasATrailingSlash() {
        XCTAssertEqual(ParkioAPI.anonymousIdentityPath, "/api/identity/anonymous/")
    }

    func testEveryVenuePathEndsInASlashForEveryRealVenue() {
        for key in DiningVenueKeys.byStableID.values {
            XCTAssertTrue(ParkioAPI.ratingsPath(venueKey: key).hasSuffix("/"))
            XCTAssertTrue(ParkioAPI.myRatingPath(venueKey: key).hasSuffix("/"))
        }
    }

    func testReleaseBuildsPointAtProduction() {
        XCTAssertEqual(ParkioAPI.productionBaseURL.absoluteString, "https://parkio.info")
    }

    func testUrlsResolveAgainstTheConfiguredHost() {
        let url = ParkioAPI.url(path: ParkioAPI.ratingsPath(venueKey: "ep-le-cellier"), base: testBaseURL)
        XCTAssertEqual(
            url?.absoluteString,
            "https://preview.example.parkio.pages.dev/api/dining/ep-le-cellier/ratings/"
        )
    }

    func testPathEscapingLeavesRealVenueKeysUntouched() {
        // venueKeys are [a-z0-9-]; escaping must not mangle them.
        for key in DiningVenueKeys.byStableID.values {
            XCTAssertTrue(ParkioAPI.ratingsPath(venueKey: key).contains(key))
        }
    }
}
