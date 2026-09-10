import XCTest

/// End-to-end lifecycle against a real Parkio Preview deployment.
///
/// Skipped unless PARKIO_PREVIEW_BASE_URL is set, so `swift test` stays
/// hermetic and no ordinary run writes to a live database.
///
///   PARKIO_PREVIEW_BASE_URL=https://…pages.dev swift test \
///     --filter PreviewIntegrationTests
///
/// It uses an in-memory credential store rather than the Keychain, both so the
/// run leaves nothing on the machine and so the credential can be printed for
/// the narrow cleanup that follows.
final class PreviewIntegrationTests: XCTestCase {

    private var baseURL: URL?

    override func setUp() {
        super.setUp()
        if let raw = ProcessInfo.processInfo.environment["PARKIO_PREVIEW_BASE_URL"],
           let url = URL(string: raw) {
            baseURL = url
        }
    }

    func testFullAnonymousRatingLifecycle() async throws {
        guard let baseURL else {
            throw XCTSkip("PARKIO_PREVIEW_BASE_URL not set")
        }

        let venue = "ep-le-cellier"
        let store = InMemoryRatingCredentialStore()
        let service = CommunityRatingService(
            transport: URLSession.shared,
            credentials: store,
            baseURL: baseURL
        )

        // 1. Aggregate starts at zero — a fact, with a nil average.
        let before = try await service.aggregate(venueKey: venue)
        XCTAssertEqual(before.ratingCount, 0, "preview must start clean")
        XCTAssertNil(before.overallAverage)
        XCTAssertFalse(before.hasRatings)

        // 2. No identity yet, and reading did not create one.
        XCTAssertNil(try store.load(), "a public read must not mint identity")

        // 3. No personal rating, and asking still does not create an identity.
        let mineBefore = try await service.myRating(venueKey: venue)
        XCTAssertNil(mineBefore)
        XCTAssertNil(try store.load(), "asking for my rating must not mint identity")

        // 4. Create. This is the first moment an identity is provisioned.
        let created = try await service.submit(
            DiningRatingSubmission(overall: 4, taste: 5, value: 3),
            venueKey: venue
        )
        XCTAssertEqual(created.outcome, .created)
        XCTAssertEqual(created.rating.overall, 4)
        XCTAssertEqual(created.rating.taste, 5)
        XCTAssertEqual(created.rating.value, 3)
        XCTAssertNil(created.rating.quality, "an unanswered dimension stays nil, not 0")

        let credential = try XCTUnwrap(try store.load(), "submitting must provision identity")
        XCTAssertTrue(credential.hasPrefix("v1."))

        // 5. The aggregate the server returned is authoritative.
        XCTAssertEqual(created.aggregate?.ratingCount, 1)
        XCTAssertEqual(created.aggregate?.overallAverage, 4)
        XCTAssertNil(created.aggregate?.qualityAverage)
        XCTAssertEqual(created.aggregate?.qualityCount, 0)

        // 6. A fresh read agrees.
        let after = try await service.aggregate(venueKey: venue)
        XCTAssertEqual(after.ratingCount, 1)
        XCTAssertEqual(after.overallAverage, 4)

        // 7. The personal rating round-trips.
        let fetched = try await service.myRating(venueKey: venue)
        let mine = try XCTUnwrap(fetched)
        XCTAssertEqual(mine.overall, 4)
        XCTAssertEqual(mine.taste, 5)
        XCTAssertEqual(mine.value, 3)
        XCTAssertNil(mine.quality)

        // 8. Update — and the count must not stack.
        let updated = try await service.submit(
            DiningRatingSubmission(overall: 2, taste: 5, value: 3, quality: 4),
            venueKey: venue
        )
        XCTAssertEqual(updated.outcome, .updated)
        XCTAssertEqual(updated.aggregate?.ratingCount, 1, "an update must not add a vote")
        XCTAssertEqual(updated.aggregate?.overallAverage, 2)
        XCTAssertEqual(updated.aggregate?.qualityAverage, 4)

        // 9. Identity was reused, not replaced.
        XCTAssertEqual(try store.load(), credential, "update must reuse the same identity")

        // 10. A second identity is genuinely separate.
        let otherStore = InMemoryRatingCredentialStore()
        let other = CommunityRatingService(
            transport: URLSession.shared, credentials: otherStore, baseURL: baseURL
        )
        let otherRating = try await other.myRating(venueKey: venue)
        XCTAssertNil(otherRating, "a different identity must not see this rating")

        // 11. A venue outside the pilot is refused before any request is sent.
        XCTAssertNil(DiningVenueKeys.venueKey(forStableID: "Magic Kingdom|Liberty Square|Columbia Harbour House"))

        // Emit exactly what must be cleaned up, and nothing secret.
        let raterId = credential.split(separator: ".")[1]
        print("PREVIEW_SYNTHETIC_ROW venue_key=\(venue) rater_id=\(raterId)")
    }
}

/// The Community section's state machine driven against a real Preview
/// deployment — the same view model the SwiftUI section binds to, so this
/// exercises exactly what a guest's taps would, minus the pixels.
///
/// Skipped unless PARKIO_PREVIEW_BASE_URL is set.
@MainActor
final class PreviewViewModelLifecycleTests: XCTestCase {

    private func settle() async {
        for _ in 0..<40 {
            await Task.yield()
            try? await Task.sleep(nanoseconds: 25_000_000)
        }
    }

    func testGuestFacingLifecycleAgainstPreview() async throws {
        guard let raw = ProcessInfo.processInfo.environment["PARKIO_PREVIEW_BASE_URL"],
              let baseURL = URL(string: raw) else {
            throw XCTSkip("PARKIO_PREVIEW_BASE_URL not set")
        }

        let venue = "ep-le-cellier"
        let store = InMemoryRatingCredentialStore()
        let service = CommunityRatingService(
            transport: URLSession.shared, credentials: store, baseURL: baseURL
        )
        let vm = CommunityRatingViewModel(venueKey: venue, service: service)

        // 1–3. Opening the venue shows the zero state, not a fabricated 0.0.
        vm.loadIfNeeded()
        await settle()
        XCTAssertEqual(vm.load, .zero, "preview must start clean")
        XCTAssertTrue(vm.visibleDimensions.isEmpty)

        // 4. Passive browsing created no identity.
        XCTAssertNil(try store.load(), "browsing must not mint a credential")
        XCTAssertFalse(vm.hasPersonalRating)

        // 5–9. Open the form and answer Overall, Taste, Value — Quality unset.
        vm.openForm()
        XCTAssertEqual(vm.form, .editing)
        XCTAssertFalse(vm.canSubmit, "Overall is required")
        vm.draftOverall = 4
        vm.draftTaste = 5
        vm.draftValue = 3
        XCTAssertTrue(vm.canSubmit)

        // 10–13. Submit: created, aggregate 4.0 / 1 rating, Quality absent.
        await vm.submit()
        XCTAssertEqual(vm.form, .success(.created))

        guard case .rated(let created) = vm.load else { return XCTFail("expected rated") }
        XCTAssertEqual(created.ratingCount, 1)
        XCTAssertEqual(created.overallAverage, 4)
        XCTAssertEqual(vm.visibleDimensions.map(\.name), ["Taste", "Value"])
        XCTAssertFalse(vm.visibleDimensions.contains { $0.name == "Quality" })

        let credential = try XCTUnwrap(try store.load(), "submitting provisions identity")

        // 14–16. A fresh view model — as if the screen were reopened — restores
        // the personal rating from the server and offers "Update rating".
        let reopened = CommunityRatingViewModel(
            venueKey: venue,
            service: CommunityRatingService(
                transport: URLSession.shared, credentials: store, baseURL: baseURL
            )
        )
        reopened.loadIfNeeded()
        await settle()
        XCTAssertTrue(reopened.hasPersonalRating, "the guest's own rating must come back")
        XCTAssertEqual(reopened.myRating?.overall, 4)
        XCTAssertEqual(reopened.myRating?.taste, 5)
        XCTAssertNil(reopened.myRating?.quality)

        // 17–19. Edit: Overall 4→2, add Quality 4.
        reopened.openForm()
        XCTAssertEqual(reopened.draftOverall, 4, "the form prefills from the server")
        XCTAssertNil(reopened.draftQuality)
        reopened.draftOverall = 2
        reopened.draftQuality = 4
        await reopened.submit()

        // 20–22. Updated, count still 1, average 2.0, Quality now present.
        XCTAssertEqual(reopened.form, .success(.updated))
        guard case .rated(let updated) = reopened.load else { return XCTFail("expected rated") }
        XCTAssertEqual(updated.ratingCount, 1, "an update must not add a vote")
        XCTAssertEqual(updated.overallAverage, 2)
        XCTAssertTrue(reopened.visibleDimensions.contains { $0.name == "Quality" })

        // Identity reused, not replaced.
        XCTAssertEqual(try store.load(), credential)

        // 23. An ineligible venue is refused before any request is possible.
        XCTAssertNil(CommunityRatingService.venueKey(forStableID: "Magic Kingdom|Liberty Square|Columbia Harbour House"))

        let raterId = credential.split(separator: ".")[1]
        print("PREVIEW_SYNTHETIC_ROW venue_key=\(venue) rater_id=\(raterId)")
    }
}
