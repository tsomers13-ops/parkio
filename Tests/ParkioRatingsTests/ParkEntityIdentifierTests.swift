import XCTest

@testable import Parkio

/// Regression guard for `Park.themeparksEntityId` — the UUID
/// `ParkHoursAPIService` builds its live-hours request URL from
/// (Parkio/Services/ParkHoursAPIService.swift:140). A wrong value here does
/// not crash; it silently 404s and the app falls back to static hours, which
/// is exactly why a static test is worth having: nothing else catches drift.
///
/// This is deliberately NOT a live-network test — it only pins the literal
/// values against a syntax check and an explicit expected-value table, so a
/// future accidental edit (or a copy-paste typo like the one fixed for
/// Animal Kingdom on 2026-10-05) fails immediately without hitting the
/// network.
final class ParkEntityIdentifierTests: XCTestCase {

    func testEveryParkHasAWellFormedThemeparksEntityId() {
        for park in Park.allCases {
            XCTAssertNotNil(
                UUID(uuidString: park.themeparksEntityId),
                "\(park.displayName) has a malformed themeparksEntityId: '\(park.themeparksEntityId)'"
            )
        }
    }

    /// Verified live against GET https://api.themeparks.wiki/v1/destinations
    /// on 2026-10-05. Magic Kingdom's value is known-stale as of this date
    /// (confirmed 404) but intentionally left unchanged here — correcting it
    /// is out of scope for this change and requires its own Product review.
    func testThemeparksEntityIdsMatchTheLastVerifiedPass() {
        XCTAssertEqual(Park.epcot.themeparksEntityId, "47f90d2c-e191-4239-a466-5892ef59a88b")
        XCTAssertEqual(Park.hollywoodStudios.themeparksEntityId, "288747d1-8b4f-4a64-867e-ea7c9b27bad8")
        XCTAssertEqual(Park.animalKingdom.themeparksEntityId, "1c84a229-8862-4648-9c71-378ddd2c7693")
        XCTAssertEqual(Park.disneyland.themeparksEntityId, "7340550b-c14d-4def-80bb-acdb51d49a66")
        XCTAssertEqual(Park.californiaAdventure.themeparksEntityId, "832fcd51-ea19-4e77-85c7-75d5843b127c")
    }
}
