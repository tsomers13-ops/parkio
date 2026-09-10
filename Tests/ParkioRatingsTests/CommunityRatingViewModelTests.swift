import XCTest

/// The Community section's state machine, driven through the fake transport so
/// every visible state and every submission outcome can be asserted without a
/// network or a view.
@MainActor
final class CommunityRatingViewModelTests: XCTestCase {

    private let venue = "ep-le-cellier"

    private let ratedBody = """
    {"venueKey":"ep-le-cellier","ratingCount":328,"overallAverage":4.638,
     "tasteAverage":4.7,"tasteCount":300,"valueAverage":4.2,"valueCount":40,
     "qualityAverage":null,"qualityCount":0}
    """
    private let zeroBody = """
    {"venueKey":"ep-le-cellier","ratingCount":0,"overallAverage":null,
     "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
     "qualityAverage":null,"qualityCount":0}
    """
    private let noPersonal = #"{"venueKey":"ep-le-cellier","rating":null}"#

    private func model(
        _ transport: FakeTransport,
        credentials: RatingCredentialStore = InMemoryRatingCredentialStore()
    ) -> CommunityRatingViewModel {
        CommunityRatingViewModel(
            venueKey: venue,
            service: makeService(transport, credentials: credentials)
        )
    }

    private func settle() async {
        for _ in 0..<50 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 2_000_000)
        }
    }

    // MARK: - Load states

    func testStartsIdle() {
        XCTAssertEqual(model(FakeTransport([])).load, .idle)
    }

    func testRatedState() async {
        let vm = model(FakeTransport([.init(200, ratedBody)]))
        vm.loadIfNeeded()
        await settle()

        guard case .rated(let aggregate) = vm.load else { return XCTFail("expected rated") }
        XCTAssertEqual(aggregate.ratingCount, 328)
        XCTAssertEqual(aggregate.overallAverage, 4.638)
    }

    func testZeroStateIsNotUnavailable() async {
        let vm = model(FakeTransport([.init(200, zeroBody)]))
        vm.loadIfNeeded()
        await settle()
        XCTAssertEqual(vm.load, .zero)
    }

    func testUnavailableStateIsNotZero() async {
        let vm = model(FakeTransport([.init(503, #"{"error":"ratings_unavailable"}"#)]))
        vm.loadIfNeeded()
        await settle()
        XCTAssertEqual(vm.load, .unavailable)
    }

    func testUnavailableNeverBecomesAZeroAggregate() async {
        let vm = model(FakeTransport([.init(503, "{}")]))
        vm.loadIfNeeded()
        await settle()
        if case .rated = vm.load { XCTFail("an outage must not present as ratings") }
        if case .zero = vm.load { XCTFail("an outage must not present as 'no ratings yet'") }
    }

    // MARK: - Dimensions

    func testOmitsDimensionsNobodyAnswered() async {
        let vm = model(FakeTransport([.init(200, ratedBody)]))
        vm.loadIfNeeded()
        await settle()

        let names = vm.visibleDimensions.map(\.name)
        XCTAssertEqual(names, ["Taste", "Value"])
        XCTAssertFalse(names.contains("Quality"), "a dimension with count 0 must be omitted, not shown as 0.0")
    }

    func testDimensionsCarryTheirOwnCounts() async {
        let vm = model(FakeTransport([.init(200, ratedBody)]))
        vm.loadIfNeeded()
        await settle()

        let rows = Dictionary(uniqueKeysWithValues: vm.visibleDimensions.map { ($0.name, $0.count) })
        // 328 overall, but only 300 tastes and 40 values — independent denominators.
        XCTAssertEqual(rows["Taste"], 300)
        XCTAssertEqual(rows["Value"], 40)
        XCTAssertNotEqual(rows["Value"], 328)
    }

    func testNoDimensionsWhenUnrated() async {
        let vm = model(FakeTransport([.init(200, zeroBody)]))
        vm.loadIfNeeded()
        await settle()
        XCTAssertTrue(vm.visibleDimensions.isEmpty)
    }

    // MARK: - Identity

    func testBrowsingCreatesNoCredential() async {
        let store = InMemoryRatingCredentialStore()
        let transport = FakeTransport([.init(200, ratedBody)])
        let vm = model(transport, credentials: store)

        vm.loadIfNeeded()
        await settle()

        XCTAssertNil(try store.load(), "opening a venue must not mint an identity")
        XCTAssertNil(transport.authorization(at: 0))
        // Only the aggregate: /me is skipped entirely with no credential.
        XCTAssertEqual(transport.requests.count, 1)
    }

    func testPersonalRatingLoadsWhenACredentialExists() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let personal = #"{"venueKey":"ep-le-cellier","rating":{"overall":4,"taste":5,"value":null,"quality":null}}"#
        let vm = model(FakeTransport([.init(200, ratedBody), .init(200, personal)]), credentials: store)

        vm.loadIfNeeded()
        await settle()

        XCTAssertTrue(vm.hasPersonalRating)
        XCTAssertEqual(vm.myRating?.overall, 4)
    }

    // MARK: - Bounded network behaviour

    func testRepeatedLoadCallsIssueOneRequest() async {
        let transport = FakeTransport([.init(200, ratedBody)])
        let vm = model(transport)

        // SwiftUI recomputes bodies freely; this must not become a request loop.
        for _ in 0..<25 { vm.loadIfNeeded() }
        await settle()
        for _ in 0..<25 { vm.loadIfNeeded() }
        await settle()

        XCTAssertEqual(transport.requests.count, 1)
    }

    func testOpeningAndClosingTheFormIssuesNoRequests() async {
        let transport = FakeTransport([.init(200, ratedBody)])
        let vm = model(transport)
        vm.loadIfNeeded()
        await settle()

        vm.openForm(); vm.closeForm(); vm.openForm(); vm.closeForm()
        await settle()

        XCTAssertEqual(transport.requests.count, 1)
    }

    // MARK: - Form

    func testSubmitBlockedUntilOverallSelected() async {
        let vm = model(FakeTransport([.init(200, zeroBody)]))
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        XCTAssertFalse(vm.canSubmit, "Overall is required")

        vm.draftTaste = 5
        XCTAssertFalse(vm.canSubmit, "an optional dimension must not satisfy the requirement")

        vm.draftOverall = 4
        XCTAssertTrue(vm.canSubmit)
    }

    func testFormOpensEmptyForAFirstRating() async {
        let vm = model(FakeTransport([.init(200, zeroBody)]))
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        XCTAssertNil(vm.draftOverall)
        XCTAssertNil(vm.draftTaste)
        XCTAssertNil(vm.draftValue)
        XCTAssertNil(vm.draftQuality)
    }

    func testFormPrefillsFromTheServerRating() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let personal = #"{"venueKey":"ep-le-cellier","rating":{"overall":4,"taste":5,"value":null,"quality":null}}"#
        let vm = model(FakeTransport([.init(200, ratedBody), .init(200, personal)]), credentials: store)
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        XCTAssertEqual(vm.draftOverall, 4)
        XCTAssertEqual(vm.draftTaste, 5)
        XCTAssertNil(vm.draftValue, "an unanswered dimension stays unselected")
        XCTAssertNil(vm.draftQuality)
    }

    // MARK: - Create vs update

    func testFirstRatingReportsCreated() async {
        let vm = model(FakeTransport([
            .init(200, zeroBody),
            .init(201, #"{"credential":"v1.new.sig"}"#),
            .init(201, """
            {"rating":{"overall":4,"taste":null,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":1,"overallAverage":4,
              "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ]))
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        vm.draftOverall = 4
        await vm.submit()

        // The Gate 3 website bug was a first rating being announced as an
        // update. The outcome comes from the response, not from local state.
        XCTAssertEqual(vm.form, .success(.created))
    }

    func testUpdateReportsUpdated() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let personal = #"{"venueKey":"ep-le-cellier","rating":{"overall":4,"taste":null,"value":null,"quality":null}}"#
        let vm = model(FakeTransport([
            .init(200, ratedBody),
            .init(200, personal),
            .init(200, """
            {"rating":{"overall":2,"taste":null,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":328,"overallAverage":4.6,
              "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ]), credentials: store)
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        vm.draftOverall = 2
        await vm.submit()

        XCTAssertEqual(vm.form, .success(.updated))
    }

    // MARK: - Authoritative aggregate

    func testAggregateComesFromTheServerNotFromLocalArithmetic() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let personal = #"{"venueKey":"ep-le-cellier","rating":{"overall":4,"taste":null,"value":null,"quality":null}}"#
        let vm = model(FakeTransport([
            .init(200, ratedBody),
            .init(200, personal),
            .init(200, """
            {"rating":{"overall":2,"taste":null,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":328,"overallAverage":4.5,
              "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ]), credentials: store)
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        vm.draftOverall = 2
        await vm.submit()

        guard case .rated(let aggregate) = vm.load else { return XCTFail("expected rated") }
        // An update must not add a vote: 328 in, 328 out.
        XCTAssertEqual(aggregate.ratingCount, 328)
        XCTAssertEqual(aggregate.overallAverage, 4.5)
    }

    func testZeroBecomesRatedImmediatelyAfterCreate() async {
        let vm = model(FakeTransport([
            .init(200, zeroBody),
            .init(201, #"{"credential":"v1.new.sig"}"#),
            .init(201, """
            {"rating":{"overall":4,"taste":null,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":1,"overallAverage":4,
              "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ]))
        vm.loadIfNeeded()
        await settle()
        XCTAssertEqual(vm.load, .zero)

        vm.openForm()
        vm.draftOverall = 4
        await vm.submit()

        // Updated from the POST response — no second GET, no cache wait.
        guard case .rated(let aggregate) = vm.load else { return XCTFail("expected rated") }
        XCTAssertEqual(aggregate.ratingCount, 1)
        XCTAssertTrue(vm.hasPersonalRating)
    }

    // MARK: - Failure

    func testFailedSubmitKeepsSelectionsAndDoesNotClaimSuccess() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let vm = model(FakeTransport([
            .init(200, zeroBody),
            .init(200, noPersonal),
            .init(503, #"{"error":"ratings_write_failed"}"#),
        ]), credentials: store)
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        vm.draftOverall = 4
        vm.draftTaste = 5
        vm.draftValue = 3
        await vm.submit()

        XCTAssertEqual(vm.form, .failure)
        XCTAssertEqual(vm.draftOverall, 4, "a failure must keep the guest's selections")
        XCTAssertEqual(vm.draftTaste, 5)
        XCTAssertEqual(vm.draftValue, 3)
        XCTAssertNil(vm.myRating, "a failed write must not look like a saved rating")
        XCTAssertEqual(vm.load, .zero, "a failed write must not change the visible aggregate")
    }

    func testFailedSubmitCanBeRetried() async {
        let store = InMemoryRatingCredentialStore(credential: "v1.abc.sig")
        let vm = model(FakeTransport([
            .init(200, zeroBody),
            .init(200, noPersonal),
            .init(503, #"{"error":"ratings_write_failed"}"#),
            .init(201, """
            {"rating":{"overall":4,"taste":null,"value":null,"quality":null},
             "aggregate":{"venueKey":"ep-le-cellier","ratingCount":1,"overallAverage":4,
              "tasteAverage":null,"tasteCount":0,"valueAverage":null,"valueCount":0,
              "qualityAverage":null,"qualityCount":0}}
            """),
        ]), credentials: store)
        vm.loadIfNeeded()
        await settle()

        vm.openForm()
        vm.draftOverall = 4
        await vm.submit()
        XCTAssertEqual(vm.form, .failure)

        await vm.submit()
        XCTAssertEqual(vm.form, .success(.created))
    }
}
