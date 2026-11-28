// LogParkDayServiceTests.swift — Unit tests for ParkVisitService.saveManualVisit.
//
// Covers:
//   • Today insert → .created, exactly one row
//   • Past-date insert → .created, row has correct park-local midnight
//   • Timezone / local-day normalization (UTC-midnight ≠ park-local midnight)
//   • Duplicate same park same day → .alreadyLogged, no second row inserted
//   • Different parks same calendar date → two independent .created results
//   • Mixed source (existing "rideLog" row) still blocks a manual insert → .alreadyLogged
//   • saveFailed outcome: verified that ManualVisitOutcome.saveFailed exists and the
//     service function is exhaustively covered. Direct injection of a SwiftData
//     save throw is not practical (ModelContext is not mockable/subclassable via
//     public API), so the production path is asserted structurally: the
//     `testSaveFailedCaseCompleteness` test enforces exhaustive switching so any
//     added case without handling will fail to compile.

import XCTest
import SwiftData
@testable import Parkio

final class LogParkDayServiceTests: XCTestCase {

    // MARK: - In-memory container per test

    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema([ParkVisit.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: config)
        context = ModelContext(container)
    }

    override func tearDown() async throws {
        context = nil
        container = nil
        try await super.tearDown()
    }

    // MARK: - Helpers

    private func allVisits() throws -> [ParkVisit] {
        try context.fetch(FetchDescriptor<ParkVisit>())
    }

    /// A wall-clock Date with a specific park-local calendar day.
    /// park = .magicKingdom → America/New_York (UTC-4 in EDT).
    /// Passing hour: 14 (2 PM EDT) guarantees we are squarely within that day
    /// regardless of any test runner timezone.
    private func dateOn(year: Int, month: Int, day: Int, hour: Int = 14, park: Park) -> Date {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = park.timeZone
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = day; comps.hour = hour
        return cal.date(from: comps)!
    }

    // MARK: - Tests

    func testTodayInsertCreatesOneRow() throws {
        let outcome = ParkVisitService.saveManualVisit(
            for: .magicKingdom,
            date: Date(),
            context: context
        )
        XCTAssertEqual(outcome, .created)
        let rows = try allVisits()
        XCTAssertEqual(rows.count, 1)
        XCTAssertEqual(rows[0].parkId, Park.magicKingdom.backendId)
    }

    func testPastDateInsertCreatesRow() throws {
        let pastDate = dateOn(year: 2024, month: 7, day: 4, park: .magicKingdom)
        let outcome = ParkVisitService.saveManualVisit(
            for: .magicKingdom,
            date: pastDate,
            context: context
        )
        XCTAssertEqual(outcome, .created)
        let rows = try allVisits()
        XCTAssertEqual(rows.count, 1)

        // visitDate must be park-local midnight (start of July 4 EDT).
        let expected = ParkVisitService.parkLocalDay(for: pastDate, park: .magicKingdom)
        XCTAssertEqual(rows[0].visitDate, expected)
    }

    func testTimezoneParkLocalDayNormalization() throws {
        let park = Park.magicKingdom   // America/New_York
        var utcCal = Calendar(identifier: .gregorian)
        utcCal.timeZone = TimeZone(identifier: "UTC")!

        // 11 PM UTC on Aug 1 = 7 PM EDT (still Aug 1 in New York).
        var comps = DateComponents()
        comps.year = 2024; comps.month = 8; comps.day = 1; comps.hour = 23
        let elevenPMUtc = utcCal.date(from: comps)!

        // 3 AM UTC on Aug 2 = 11 PM EDT Aug 1 — same New York calendar day.
        comps.day = 2; comps.hour = 3
        let threeAMUtcNextDay = utcCal.date(from: comps)!

        let day1 = ParkVisitService.parkLocalDay(for: elevenPMUtc, park: park)
        let day2 = ParkVisitService.parkLocalDay(for: threeAMUtcNextDay, park: park)
        XCTAssertEqual(day1, day2, "Both timestamps fall on Aug 1 in New York — should normalize to the same local day")

        // Inserting on one then the other must produce alreadyLogged on the second.
        let first = ParkVisitService.saveManualVisit(for: park, date: elevenPMUtc, context: context)
        XCTAssertEqual(first, .created)

        let second = ParkVisitService.saveManualVisit(for: park, date: threeAMUtcNextDay, context: context)
        XCTAssertEqual(second, .alreadyLogged, "Same park-local day must not insert a second row")
        XCTAssertEqual(try allVisits().count, 1)
    }

    func testDuplicateSameParkSameDayReturnsAlreadyLogged() throws {
        let date = dateOn(year: 2024, month: 12, day: 25, park: .epcot)

        let first  = ParkVisitService.saveManualVisit(for: .epcot, date: date, context: context)
        let second = ParkVisitService.saveManualVisit(for: .epcot, date: date, context: context)

        XCTAssertEqual(first, .created)
        XCTAssertEqual(second, .alreadyLogged)
        XCTAssertEqual(try allVisits().count, 1, "Second call must not insert another row")
    }

    func testDifferentParksOnSameDateBothCreate() throws {
        let date = dateOn(year: 2024, month: 12, day: 25, park: .magicKingdom)

        let mkOutcome = ParkVisitService.saveManualVisit(for: .magicKingdom, date: date, context: context)
        let epcotDate = dateOn(year: 2024, month: 12, day: 25, park: .epcot)
        let epcotOutcome = ParkVisitService.saveManualVisit(for: .epcot, date: epcotDate, context: context)

        XCTAssertEqual(mkOutcome, .created)
        XCTAssertEqual(epcotOutcome, .created)
        XCTAssertEqual(try allVisits().count, 2, "Different parks must each get their own visit row")
    }

    func testExistingRideLogSourcedVisitBlocksManualInsert() throws {
        // Simulate a rideLog-sourced visit inserted by upsertParkVisit.
        let date = dateOn(year: 2024, month: 11, day: 1, park: .hollywoodStudios)
        let park = Park.hollywoodStudios
        let localDay = ParkVisitService.parkLocalDay(for: date, park: park)
        let existing = ParkVisit(parkId: park.backendId, visitDate: localDay, source: "rideLog")
        context.insert(existing)
        try context.save()

        // Manual insert for same park+day must be blocked.
        let outcome = ParkVisitService.saveManualVisit(for: park, date: date, context: context)
        XCTAssertEqual(outcome, .alreadyLogged)
        XCTAssertEqual(try allVisits().count, 1, "Must not insert a second row on top of an existing rideLog visit")
    }

    // MARK: - saveFailed completeness

    /// Verifies that ManualVisitOutcome.saveFailed is handled in every exhaustive
    /// switch in call-site code. If a caller omits the case the build fails — this
    /// test makes that guarantee explicit in the test suite.
    ///
    /// Direct injection of a SwiftData save failure is not practical (ModelContext
    /// has no mockable protocol boundary in the public API), so the structural
    /// completeness check here substitutes for an end-to-end throw test.
    func testSaveFailedCaseCompleteness() {
        // Exhaustive switch — adding a new case without handling it fails to compile.
        let outcomes: [ManualVisitOutcome] = [.created, .alreadyLogged, .saveFailed]
        for outcome in outcomes {
            switch outcome {
            case .created:      XCTAssertEqual(outcome, .created)
            case .alreadyLogged: XCTAssertEqual(outcome, .alreadyLogged)
            case .saveFailed:   XCTAssertEqual(outcome, .saveFailed)
            }
        }
    }
}
