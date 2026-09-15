import XCTest

/// HTTP 429 handling for Community Ratings.
///
/// The backend rate-limits the two write paths — minting a native identity and
/// submitting a rating. The point of these tests is not merely that 429 maps to
/// `rateLimited`, but that it stays *out* of the 401 recovery path: a limited
/// request must not cost the guest their stored credential, and must not be
/// retried, because retrying is exactly what the limit exists to prevent.
final class RateLimitTests: XCTestCase {

    private let venue = "ep-le-cellier"
    private let rateLimitedBody = #"{"error":"rate_limited","message":"Too many requests. Please slow down."}"#

    // MARK: - Mint

    func testMintRateLimitMapsToRateLimited() async {
        // No stored credential, so submitting must mint first — and the mint is
        // what gets limited here.
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport([.init(429, rateLimitedBody)])
        let service = makeService(transport, credentials: store)

        await assertThrows(.rateLimited) {
            try await service.submit(DiningRatingSubmission(overall: 5), venueKey: self.venue)
        }
        XCTAssertEqual(transport.requests.count, 1, "the limited mint must not be retried")
        XCTAssertNil(try? store.load(), "a limited mint stores nothing")
    }

    func testMintRateLimitIsNotConfusedWithServiceUnavailable() async {
        let transport = FakeTransport([.init(429, rateLimitedBody)])
        let service = makeService(transport, credentials: InMemoryRatingCredentialStore())

        do {
            _ = try await service.submit(DiningRatingSubmission(overall: 3), venueKey: venue)
            XCTFail("expected rateLimited")
        } catch let error as CommunityRatingError {
            XCTAssertEqual(error, .rateLimited)
            XCTAssertNotEqual(error, .serviceUnavailable)
            XCTAssertNotEqual(error, .invalidCredential)
        } catch {
            XCTFail("unexpected \(error)")
        }
    }

    // MARK: - Write

    func testRatingWriteRateLimitMapsToRateLimited() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport([.init(429, rateLimitedBody)])
        let service = makeService(transport, credentials: store)

        await assertThrows(.rateLimited) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
    }

    // MARK: - The two properties that matter most

    func testRateLimitDoesNotDeleteTheCredential() async {
        // A 429 says "slow down", not "who are you". Losing the credential here
        // would silently detach the guest from every rating they have left.
        let store = InMemoryRatingCredentialStore(credential: "v1.keepme.sig")
        let service = makeService(FakeTransport([.init(429, rateLimitedBody)]), credentials: store)

        await assertThrows(.rateLimited) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
        XCTAssertEqual(try store.load(), "v1.keepme.sig")
    }

    func testRateLimitIsNeverRetried() async {
        // Exactly one request. No remint, no second write, no backoff loop.
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport([.init(429, rateLimitedBody)])
        let service = makeService(transport, credentials: store)

        await assertThrows(.rateLimited) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(transport.methods, ["POST"])
        XCTAssertEqual(transport.authorization(at: 0), "Bearer v1.abc.sig")
    }

    func testRateLimitDoesNotEnterTheCredentialRecoveryPath() async {
        // If 429 were ever treated as a stale credential, the service would mint
        // and write again and these stubs would be consumed. They must not be.
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport([
            .init(429, rateLimitedBody),
            .init(201, #"{"credential":"v1.should-not-be-minted.sig"}"#),
            .init(201, #"{"rating":{"overall":4,"taste":null,"value":null,"quality":null},"aggregate":null}"#),
        ])
        let service = makeService(transport, credentials: store)

        await assertThrows(.rateLimited) {
            try await service.submit(DiningRatingSubmission(overall: 4), venueKey: self.venue)
        }
        XCTAssertEqual(transport.requests.count, 1, "no remint, no retry")
        XCTAssertEqual(try store.load(), "v1.abc.sig", "credential untouched")
    }

    // MARK: - Regression guards on the behaviour 429 must not disturb

    func testStaleCredentialStillSelfHealsOn401() async throws {
        // The 401 path is unchanged: discard, remint, retry exactly once.
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

    func testSuccessfulSubmissionIsUnchanged() async throws {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let transport = FakeTransport([
            .init(201, """
            {"rating":{"overall":5,"taste":4,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":1,"overallAverage":5,
              "tasteAverage":4,"tasteCount":1,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ])

        let result = try await makeService(transport, credentials: store)
            .submit(DiningRatingSubmission(overall: 5, taste: 4), venueKey: venue)

        XCTAssertEqual(result.outcome, .created)
        XCTAssertEqual(result.rating.overall, 5)
        XCTAssertEqual(result.aggregate?.ratingCount, 1)
        XCTAssertEqual(transport.requests.count, 1)
        XCTAssertEqual(try store.load(), "v1.abc.sig")
    }

    // MARK: - Copy

    func testRateLimitCopyIsGuestFacing() {
        let message = CommunityRatingError.rateLimited.userMessage
        XCTAssertEqual(message, "Too many requests. Please wait a moment and try again.")

        // Nothing about our infrastructure belongs in a guest's error message.
        for leak in ["429", "HTTP", "Cloudflare", "IP", "limiter", "rate_limited", "/api/"] {
            XCTAssertFalse(
                message.localizedCaseInsensitiveContains(leak),
                "user-facing copy must not mention \(leak)"
            )
        }
    }

    func testRateLimitDoesNotSuggestCredentialRefresh() {
        XCTAssertFalse(CommunityRatingError.rateLimited.suggestsCredentialRefresh)
        XCTAssertTrue(CommunityRatingError.invalidCredential.suggestsCredentialRefresh)
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
