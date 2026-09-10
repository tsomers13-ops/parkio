import XCTest

/// The service layer, driven through a fake transport so every request header
/// and every failure path can be asserted without a network.
final class CommunityRatingServiceTests: XCTestCase {

    private let venue = "ep-le-cellier"

    private let ratedAggregate = """
    {"venueKey":"ep-le-cellier","ratingCount":4,"overallAverage":4.5,
     "tasteAverage":5,"tasteCount":1,"valueAverage":3,"valueCount":1,
     "qualityAverage":null,"qualityCount":0}
    """

    private let emptyAggregate = """
    {"venueKey":"ep-le-cellier","ratingCount":0,"overallAverage":null,
     "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
     "qualityAverage":null,"qualityCount":0}
    """

    // MARK: - Aggregate reads

    func testDecodesARatedAggregate() async throws {
        let service = makeService(FakeTransport(status: 200, body: ratedAggregate))
        let aggregate = try await service.aggregate(venueKey: venue)

        XCTAssertEqual(aggregate.ratingCount, 4)
        XCTAssertEqual(aggregate.overallAverage, 4.5)
        XCTAssertEqual(aggregate.tasteAverage, 5)
        XCTAssertEqual(aggregate.tasteCount, 1)
        XCTAssertTrue(aggregate.hasRatings)
    }

    func testUnratedVenueHasNilAverageNotZero() async throws {
        let service = makeService(FakeTransport(status: 200, body: emptyAggregate))
        let aggregate = try await service.aggregate(venueKey: venue)

        XCTAssertEqual(aggregate.ratingCount, 0)
        XCTAssertNil(aggregate.overallAverage)
        XCTAssertNotEqual(aggregate.overallAverage, 0)
        XCTAssertFalse(aggregate.hasRatings)
    }

    func testDimensionNobodyAnsweredIsNilNotZero() async throws {
        let service = makeService(FakeTransport(status: 200, body: ratedAggregate))
        let aggregate = try await service.aggregate(venueKey: venue)

        XCTAssertNil(aggregate.qualityAverage)
        XCTAssertEqual(aggregate.qualityCount, 0)
    }

    func testZeroAndUnavailableAreDifferentOutcomes() async throws {
        let zero = makeService(FakeTransport(status: 200, body: emptyAggregate))
        let aggregate = try await zero.aggregate(venueKey: venue)
        XCTAssertEqual(aggregate.ratingCount, 0)

        let down = makeService(FakeTransport(status: 503, body: #"{"error":"ratings_unavailable"}"#))
        await assertThrows(.serviceUnavailable) { try await down.aggregate(venueKey: self.venue) }
    }

    func testAggregateReadSendsNoCredentialAndCreatesNone() async throws {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport(status: 200, body: emptyAggregate)
        let service = makeService(transport, credentials: store)

        _ = try await service.aggregate(venueKey: venue)

        XCTAssertNil(transport.authorization(at: 0), "a public read must not be authenticated")
        XCTAssertNil(try store.load(), "browsing must not mint an identity")
        XCTAssertEqual(transport.methods, ["GET"])
    }

    func testAggregateUsesTheTrailingSlashURL() async throws {
        let transport = FakeTransport(status: 200, body: emptyAggregate)
        _ = try await makeService(transport).aggregate(venueKey: venue)
        XCTAssertTrue(transport.urls[0].hasSuffix("/api/dining/ep-le-cellier/ratings/"))
    }

    func testUnknownVenueIsReported() async {
        let service = makeService(FakeTransport(status: 404, body: #"{"error":"not_found"}"#))
        await assertThrows(.unknownVenue(venueKey: venue)) {
            try await service.aggregate(venueKey: self.venue)
        }
    }

    func testNetworkFailureIsItsOwnError() async {
        let transport = FakeTransport(status: 200, body: emptyAggregate)
        transport.transportError = URLError(.notConnectedToInternet)
        let service = makeService(transport)
        await assertThrows(.networkUnavailable) { try await service.aggregate(venueKey: self.venue) }
    }

    func testMalformedBodyIsADecodingFailure() async {
        let service = makeService(FakeTransport(status: 200, body: "{not json"))
        await assertThrows(.decodingFailed) { try await service.aggregate(venueKey: self.venue) }
    }

    // MARK: - Bulk reads

    func testBulkReadIsOneRequestForManyVenues() async throws {
        let body = """
        {"ratings":{"ep-le-cellier":{"ratingCount":4,"overallAverage":4.5},
                    "ep-akershus":{"ratingCount":0,"overallAverage":null}}}
        """
        let transport = FakeTransport(status: 200, body: body)
        let summaries = try await makeService(transport).summaries(venueKeys: ["ep-le-cellier", "ep-akershus"])

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(summaries["ep-le-cellier"]?.overallAverage, 4.5)
        XCTAssertTrue(summaries["ep-le-cellier"]!.hasRatings)
        XCTAssertFalse(summaries["ep-akershus"]!.hasRatings)
        XCTAssertNil(summaries["ep-akershus"]?.overallAverage)
    }

    func testBulkReadOfNothingMakesNoRequest() async throws {
        let transport = FakeTransport(status: 200, body: "{}")
        let summaries = try await makeService(transport).summaries(venueKeys: [])
        XCTAssertTrue(summaries.isEmpty)
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testBulkReadIsUnauthenticated() async throws {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport(status: 200, body: #"{"ratings":{}}"#)
        _ = try await makeService(transport, credentials: store).summaries(venueKeys: ["ep-le-cellier"])
        XCTAssertNil(transport.authorization(at: 0))
        XCTAssertNil(try store.load())
    }

    // MARK: - Personal rating

    func testNoCredentialMeansNoPersonalRatingAndNoRequest() async throws {
        let transport = FakeTransport(status: 200, body: #"{"venueKey":"ep-le-cellier","rating":null}"#)
        let service = makeService(transport, credentials: InMemoryRatingCredentialStore())

        let mine = try await service.myRating(venueKey: venue)

        XCTAssertNil(mine)
        XCTAssertTrue(transport.requests.isEmpty, "an unidentified guest provably has no rating")
    }

    func testPersonalRatingIsSentWithTheBearerCredential() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let body = #"{"venueKey":"ep-le-cellier","rating":{"overall":4,"taste":5,"value":null,"quality":null}}"#
        let transport = FakeTransport(status: 200, body: body)

        let mine = try await makeService(transport, credentials: store).myRating(venueKey: venue)

        XCTAssertEqual(transport.authorization(at: 0), "Bearer v1.abc.sig")
        XCTAssertEqual(mine?.overall, 4)
        XCTAssertEqual(mine?.taste, 5)
        XCTAssertNil(mine?.value)
        XCTAssertNil(mine?.quality)
    }

    func testCredentialNeverAppearsInTheURL() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.secretlooking.sig")
        let transport = FakeTransport(status: 200, body: #"{"venueKey":"ep-le-cellier","rating":null}"#)
        _ = try await makeService(transport, credentials: store).myRating(venueKey: venue)

        for url in transport.urls {
            XCTAssertFalse(url.contains("secretlooking"), "credential must never reach a URL")
            XCTAssertFalse(url.contains("Bearer"))
        }
    }

    func testRejectedCredentialIsDiscardedOnRead() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.stale.sig")
        let transport = FakeTransport(status: 401, body: #"{"error":"invalid_credential"}"#)

        let mine = try await makeService(transport, credentials: store).myRating(venueKey: venue)

        XCTAssertNil(mine)
        XCTAssertNil(try store.load(), "a rejected credential must not be kept")
    }

    func testCookiesAreNeverUsed() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport(status: 200, body: #"{"venueKey":"ep-le-cellier","rating":null}"#)
        _ = try await makeService(transport, credentials: store).myRating(venueKey: venue)

        XCTAssertFalse(transport.requests[0].httpShouldHandleCookies)
    }

    // MARK: - Submission

    func testSubmissionOmitsUnansweredDimensions() throws {
        let json = try JSONEncoder().encode(DiningRatingSubmission(overall: 4))
        let decoded = try JSONSerialization.jsonObject(with: json) as! [String: Any]

        XCTAssertEqual(decoded["overall"] as? Int, 4)
        XCTAssertFalse(decoded.keys.contains("taste"), "unanswered Taste must be absent, not null")
        XCTAssertFalse(decoded.keys.contains("value"))
        XCTAssertFalse(decoded.keys.contains("quality"))
        XCTAssertEqual(decoded.count, 1)
    }

    func testSubmissionEncodesAnsweredDimensions() throws {
        let submission = DiningRatingSubmission(overall: 4, taste: 5, value: 3)
        let decoded = try JSONSerialization.jsonObject(
            with: try JSONEncoder().encode(submission)
        ) as! [String: Any]

        XCTAssertEqual(decoded["taste"] as? Int, 5)
        XCTAssertEqual(decoded["value"] as? Int, 3)
        XCTAssertFalse(decoded.keys.contains("quality"))
    }

    func testWholeStarValidation() {
        XCTAssertTrue(DiningRatingSubmission(overall: 1).isValid)
        XCTAssertTrue(DiningRatingSubmission(overall: 5, taste: 1).isValid)
        XCTAssertFalse(DiningRatingSubmission(overall: 0).isValid)
        XCTAssertFalse(DiningRatingSubmission(overall: 6).isValid)
        XCTAssertFalse(DiningRatingSubmission(overall: 3, value: 0).isValid)
        XCTAssertFalse(DiningRatingSubmission(overall: 3, quality: 9).isValid)
    }

    func testInvalidSubmissionNeverReachesTheNetwork() async {
        let transport = FakeTransport(status: 201, body: "{}")
        let service = makeService(transport)
        await assertThrows(.notRateable) {
            try await service.submit(DiningRatingSubmission(overall: 0), venueKey: self.venue)
        }
        XCTAssertTrue(transport.requests.isEmpty)
    }

    func testFirstSubmissionProvisionsAnIdentityThenWrites() async throws {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport([
            .init(201, #"{"credential":"v1.new.sig"}"#),
            .init(201, #"{"rating":{"overall":4,"taste":null,"value":null,"quality":null},"aggregate":null}"#),
        ])

        let result = try await makeService(transport, credentials: store)
            .submit(DiningRatingSubmission(overall: 4), venueKey: venue)

        XCTAssertEqual(transport.requests.count, 2)
        XCTAssertTrue(transport.urls[0].hasSuffix("/api/identity/anonymous/"))
        XCTAssertEqual(transport.methods, ["POST", "POST"])
        XCTAssertNil(transport.authorization(at: 0), "minting an identity is unauthenticated")
        XCTAssertEqual(transport.authorization(at: 1), "Bearer v1.new.sig")
        XCTAssertEqual(try store.load(), "v1.new.sig")
        XCTAssertEqual(result.outcome, .created)
    }

    func testExistingIdentityIsReusedWithoutReprovisioning() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.existing.sig")
        let transport = FakeTransport([
            .init(200, #"{"rating":{"overall":2,"taste":null,"value":null,"quality":null},"aggregate":null}"#),
        ])

        let result = try await makeService(transport, credentials: store)
            .submit(DiningRatingSubmission(overall: 2), venueKey: venue)

        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.authorization(at: 0), "Bearer v1.existing.sig")
        XCTAssertEqual(result.outcome, .updated)
    }

    func testCreateAndUpdateAreDistinguished() async throws {
        let created = FakeTransport([.init(201, #"{"rating":{"overall":4,"taste":null,"value":null,"quality":null},"aggregate":null}"#)])
        let updated = FakeTransport([.init(200, #"{"rating":{"overall":4,"taste":null,"value":null,"quality":null},"aggregate":null}"#)])
        let store = { InMemoryRatingCredentialStore(credential: "v1.abc.sig") }

        let a = try await makeService(created, credentials: store())
            .submit(DiningRatingSubmission(overall: 4), venueKey: venue)
        let b = try await makeService(updated, credentials: store())
            .submit(DiningRatingSubmission(overall: 4), venueKey: venue)

        XCTAssertEqual(a.outcome, .created)
        XCTAssertEqual(b.outcome, .updated)
    }

    func testServerAggregateIsAuthoritative() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let body = """
        {"rating":{"overall":2,"taste":null,"value":null,"quality":null},
         "aggregate":{"venueKey":"ep-le-cellier","ratingCount":1,"overallAverage":2,
          "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
          "qualityAverage":null,"qualityCount":0}}
        """
        let result = try await makeService(FakeTransport(status: 200, body: body), credentials: store)
            .submit(DiningRatingSubmission(overall: 2), venueKey: venue)

        // An update must not add a vote — the count comes from the server.
        XCTAssertEqual(result.aggregate?.ratingCount, 1)
        XCTAssertEqual(result.aggregate?.overallAverage, 2)
    }

    func testStaleCredentialIsReplacedAndTheWriteRetriedOnce() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.stale.sig")
        let transport = FakeTransport([
            .init(401, #"{"error":"invalid_credential"}"#),
            .init(201, #"{"credential":"v1.fresh.sig"}"#),
            .init(201, #"{"rating":{"overall":5,"taste":null,"value":null,"quality":null},"aggregate":null}"#),
        ])

        let result = try await makeService(transport, credentials: store)
            .submit(DiningRatingSubmission(overall: 5), venueKey: venue)

        XCTAssertEqual(transport.requests.count, 3)
        XCTAssertEqual(transport.authorization(at: 0), "Bearer v1.stale.sig")
        XCTAssertEqual(transport.authorization(at: 2), "Bearer v1.fresh.sig")
        XCTAssertEqual(try store.load(), "v1.fresh.sig")
        XCTAssertEqual(result.outcome, .created)
    }

    func testAFailedWriteIsNeverReportedAsSuccess() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let service = makeService(
            FakeTransport(status: 503, body: #"{"error":"ratings_write_failed"}"#),
            credentials: store
        )
        await assertThrows(.writeFailed) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
    }

    func testWriteIsNotRetriedOnNetworkFailure() async {
        // No offline queue, no silent retry: one attempt, then report.
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport([])
        transport.transportError = URLError(.timedOut)
        let service = makeService(transport, credentials: store)

        await assertThrows(.networkUnavailable) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
        XCTAssertEqual(transport.requests.count, 0)
    }

    func testValidationFailureFromServerIsSurfaced() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let service = makeService(
            FakeTransport(status: 400, body: #"{"error":"bad_request","message":"overall is required"}"#),
            credentials: store
        )
        await assertThrows(.validationFailed(message: "overall is required")) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
    }

    // MARK: - Helper

    private func assertThrows(
        _ expected: CommunityRatingError,
        file: StaticString = #filePath,
        line: UInt = #line,
        _ body: () async throws -> Void
    ) async {
        do {
            try await body()
            XCTFail("expected \(expected)", file: file, line: line)
        } catch let error as CommunityRatingError {
            XCTAssertEqual(error, expected, file: file, line: line)
        } catch {
            XCTFail("unexpected \(error)", file: file, line: line)
        }
    }
}
