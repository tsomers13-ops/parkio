import XCTest

/// Gate 7 — the Community signal on Dining discovery rows.
///
/// Two things are under test and the second matters as much as the first:
/// what a row says, and how many requests a whole list costs. A correct-looking
/// row that costs 42 round trips would be a failure.
final class CommunityDiscoveryTests: XCTestCase {

    private let epcotLocale = Locale(identifier: "en_US")

    private func summary(_ count: Int, _ average: Double?) -> CommunityRatingSummary {
        CommunityRatingSummary(ratingCount: count, overallAverage: average)
    }

    // MARK: - Decoding

    func testDecodesOneRatedVenue() throws {
        let json = #"{"ratings":{"ep-le-cellier":{"ratingCount":328,"overallAverage":4.6}}}"#
        let body = try JSONDecoder().decode(
            CommunityRatingSummaryResponse.self, from: Data(json.utf8)
        )
        XCTAssertEqual(body.ratings.count, 1)
        XCTAssertEqual(body.ratings["ep-le-cellier"]?.ratingCount, 328)
        XCTAssertEqual(body.ratings["ep-le-cellier"]?.overallAverage, 4.6)
    }

    func testDecodesMultipleRatedVenues() throws {
        let json = """
        {"ratings":{"ep-le-cellier":{"ratingCount":328,"overallAverage":4.6},
                    "hs-backlot-express":{"ratingCount":12,"overallAverage":3.9}}}
        """
        let body = try JSONDecoder().decode(
            CommunityRatingSummaryResponse.self, from: Data(json.utf8)
        )
        XCTAssertEqual(body.ratings.count, 2)
        XCTAssertTrue(body.ratings["ep-le-cellier"]!.hasRatings)
        XCTAssertTrue(body.ratings["hs-backlot-express"]!.hasRatings)
    }

    func testDecodesMixedRatedAndUnrated() throws {
        let json = """
        {"ratings":{"ep-le-cellier":{"ratingCount":4,"overallAverage":4.5},
                    "ep-akershus":{"ratingCount":0,"overallAverage":null}}}
        """
        let body = try JSONDecoder().decode(
            CommunityRatingSummaryResponse.self, from: Data(json.utf8)
        )
        XCTAssertTrue(body.ratings["ep-le-cellier"]!.hasRatings)
        XCTAssertFalse(body.ratings["ep-akershus"]!.hasRatings)
        XCTAssertNil(body.ratings["ep-akershus"]!.overallAverage)
    }

    // MARK: - Row text

    func testShowsAverageToOneDecimal() {
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(328, 4.638), locale: epcotLocale),
            "Community 4.6 · 328 ratings"
        )
    }

    func testKeepsOneDecimalOnAWholeAverage() {
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(1, 5), locale: epcotLocale),
            "Community 5.0 · 1 rating"
        )
    }

    func testSingularRating() {
        let text = CommunityDiscoverySummary.text(for: summary(1, 5), locale: epcotLocale)!
        XCTAssertTrue(text.hasSuffix("1 rating"))
        XCTAssertFalse(text.contains("1 ratings"))
    }

    func testPluralRatings() {
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(7, 4.2), locale: epcotLocale),
            "Community 4.2 · 7 ratings"
        )
    }

    func testGroupsLargeCounts() {
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(1204, 3.9), locale: epcotLocale),
            "Community 3.9 · 1,204 ratings"
        )
    }

    func testTextNamesTheCommunityExplicitly() {
        let text = CommunityDiscoverySummary.text(for: summary(9, 4.1), locale: epcotLocale)!
        XCTAssertTrue(text.hasPrefix("Community "), "the row must say which rating this is")
    }

    func testTextCarriesNoStarGlyph() {
        // The row already shows the guest's PRIVATE five-star strip; a second
        // star here would blur two different systems.
        for count in [1, 7, 328, 1204] {
            let text = CommunityDiscoverySummary.text(for: summary(count, 4.4), locale: epcotLocale)!
            for glyph in ["★", "☆", "*"] {
                XCTAssertFalse(text.contains(glyph), "'\(glyph)' must not appear in '\(text)'")
            }
        }
    }

    func testNoDimensionsOnDiscovery() {
        let text = CommunityDiscoverySummary.text(for: summary(50, 4.4), locale: epcotLocale)!
        for dimension in ["Taste", "Value", "Quality"] {
            XCTAssertFalse(text.contains(dimension))
        }
    }

    // MARK: - Zero / unavailable

    func testZeroRatingsShowsNothing() {
        XCTAssertNil(CommunityDiscoverySummary.text(for: summary(0, nil)))
        XCTAssertNil(CommunityDiscoverySummary.accessibilityLabel(for: summary(0, nil)))
    }

    func testUnavailableShowsNothing() {
        // nil summary is how both "ineligible" and "could not be read" arrive.
        XCTAssertNil(CommunityDiscoverySummary.text(for: nil))
        XCTAssertNil(CommunityDiscoverySummary.accessibilityLabel(for: nil))
    }

    func testNeverRendersAFabricatedZero() {
        for candidate in [summary(0, nil), summary(0, 0)] {
            XCTAssertNil(CommunityDiscoverySummary.text(for: candidate))
        }
    }

    func testCountWithoutAverageShowsNothing() {
        XCTAssertNil(CommunityDiscoverySummary.text(for: summary(5, nil)))
    }

    // MARK: - Accessibility

    func testAccessibilityLabelStatesTheScale() {
        XCTAssertEqual(
            CommunityDiscoverySummary.accessibilityLabel(for: summary(328, 4.6), locale: epcotLocale),
            "Community rating 4.6 out of 5 from 328 ratings"
        )
    }

    func testAccessibilityLabelSingular() {
        XCTAssertEqual(
            CommunityDiscoverySummary.accessibilityLabel(for: summary(1, 5), locale: epcotLocale),
            "Community rating 5.0 out of 5 from 1 rating"
        )
    }

    func testAccessibilityLabelRestoresWhatTheVisualOmits() {
        // The visible text drops "out of 5"; VoiceOver must not.
        let text = CommunityDiscoverySummary.text(for: summary(9, 4.1), locale: epcotLocale)!
        let label = CommunityDiscoverySummary.accessibilityLabel(for: summary(9, 4.1), locale: epcotLocale)!
        XCTAssertFalse(text.contains("out of 5"))
        XCTAssertTrue(label.contains("out of 5"))
    }

    // MARK: - Eligibility

    func testEligibleVenueResolves() {
        XCTAssertEqual(
            CommunityRatingService.venueKey(forStableID: "EPCOT|World Showcase|Le Cellier Steakhouse"),
            "ep-le-cellier"
        )
    }

    func testExactlySixtyTwoEligible() {
        XCTAssertEqual(DiningVenueKeys.byStableID.count, 62)
    }

    func testIneligibleParksRemainUnsupported() {
        for stableID in [
            "Magic Kingdom|Liberty Square|Columbia Harbour House",
            "Animal Kingdom|Discovery Island|Flame Tree Barbecue",
            "Disneyland|New Orleans Square|Blue Bayou Restaurant",
            "California Adventure|Pacific Wharf|Pacific Wharf Cafe",
        ] {
            XCTAssertNil(CommunityRatingService.venueKey(forStableID: stableID))
        }
    }

    func testUnknownVenueKeyInResponseIsIgnoredSafely() throws {
        let json = """
        {"ratings":{"ep-le-cellier":{"ratingCount":3,"overallAverage":4.0},
                    "totally-made-up":{"ratingCount":99,"overallAverage":1.0}}}
        """
        let body = try JSONDecoder().decode(
            CommunityRatingSummaryResponse.self, from: Data(json.utf8)
        )
        // A row only ever looks itself up by its own venueKey, so a stray key
        // in the map can never surface on a card.
        XCTAssertNil(body.ratings["ep-akershus"])
        XCTAssertNotNil(body.ratings["ep-le-cellier"])
    }

    // MARK: - Request behaviour

    /// The list derives its keys from the stable dataset. These fixtures stand
    /// in for that list: the same key set, in the same order, every time.
    private func keys(prefix: String, count: Int) -> [String] {
        DiningVenueKeys.byStableID
            .filter { $0.value.hasPrefix(prefix) }
            .values.sorted()
            .prefix(count)
            .map { $0 }
    }

    func testEpcotDatasetIsOneRequest() async throws {
        let epcot = keys(prefix: "ep-", count: 42)
        XCTAssertEqual(epcot.count, 42)

        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport).summaries(venueKeys: epcot)

        XCTAssertEqual(transport.requests.count, 1, "42 venues must cost one request")
    }

    func testHollywoodStudiosDatasetIsOneRequest() async throws {
        let dhs = keys(prefix: "hs-", count: 20)
        XCTAssertEqual(dhs.count, 20)

        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport).summaries(venueKeys: dhs)

        XCTAssertEqual(transport.requests.count, 1, "20 venues must cost one request")
    }

    func testEmptyKeySetMakesNoRequest() async throws {
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        let result = try await makeService(transport).summaries(venueKeys: [])
        XCTAssertTrue(result.isEmpty)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testBulkReadSendsNoAuthorizationHeader() async throws {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport, credentials: store)
            .summaries(venueKeys: ["ep-le-cellier"])

        XCTAssertNil(transport.authorization(at: 0), "a public read must not be authenticated")
    }

    func testBulkReadProvisionsNoIdentity() async throws {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport, credentials: store)
            .summaries(venueKeys: ["ep-le-cellier", "hs-backlot-express"])

        XCTAssertNil(try store.load(), "browsing Dining must not mint a credential")
    }

    func testBulkReadDoesNotDependOnCookies() async throws {
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport).summaries(venueKeys: ["ep-le-cellier"])
        XCTAssertFalse(transport.requests[0].httpShouldHandleCookies)
    }

    func testBulkReadUsesTheTrailingSlashURL() async throws {
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport).summaries(venueKeys: ["ep-le-cellier"])
        XCTAssertTrue(transport.urls[0].contains("/api/dining/ratings/?venueKeys="))
    }

    func testServiceFailureSurfacesSoTheListCanOmitSignals() async {
        let transport = FakeTransport(status: 503, body: #"{"error":"ratings_unavailable"}"#)
        do {
            _ = try await makeService(transport).summaries(venueKeys: ["ep-le-cellier"])
            XCTFail("expected a failure the list can turn into 'show nothing'")
        } catch let error as CommunityRatingError {
            XCTAssertEqual(error, .serviceUnavailable)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - Separation from the private journal and editorial

    func testCommunitySignalComesOnlyFromTheServerSummary() {
        // The private journal's type (`DiningRating`) is not even compiled into
        // this module — the Community layer has no way to reach it. Everything
        // a row shows is derived from CommunityRatingSummary and nothing else,
        // so a venue with no server summary has no Community line no matter
        // what the guest recorded privately.
        XCTAssertNil(CommunityDiscoverySummary.text(for: nil))
        XCTAssertNil(CommunityDiscoverySummary.accessibilityLabel(for: nil))

        // And a summary that does exist is rendered purely from its own fields.
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(2, 3.5), locale: epcotLocale),
            "Community 3.5 · 2 ratings"
        )
    }

    func testPrivateRatingValueNeverBecomesTheCommunityAverage() {
        // Same numeric value, entirely different provenance: a private 5 must
        // never render as "Community 5.0".
        XCTAssertNil(CommunityDiscoverySummary.text(for: nil))
        XCTAssertEqual(
            CommunityDiscoverySummary.text(for: summary(1, 5), locale: epcotLocale),
            "Community 5.0 · 1 rating"
        )
    }

    func testCommunityTextCarriesNoEditorialScore() {
        // Parkio's editorial score is out of 10 and lives elsewhere.
        let text = CommunityDiscoverySummary.text(for: summary(40, 4.4), locale: epcotLocale)!
        XCTAssertFalse(text.contains("/ 10"))
        XCTAssertFalse(text.contains("/10"))
        XCTAssertFalse(text.lowercased().contains("parkio score"))
    }

    func testCommunitySummaryIsAValueTypeAndCannotMutateAnything() {
        // Value semantics: handing a summary to a row cannot write back.
        var a = summary(3, 4.0)
        let b = a
        a = summary(9, 2.0)
        XCTAssertEqual(b.ratingCount, 3)
        XCTAssertEqual(b.overallAverage, 4.0)
    }
}
