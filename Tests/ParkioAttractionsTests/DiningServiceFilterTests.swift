// DiningServiceFilterTests.swift — Quick service / Sit-down classification.
//
// The mapping lives in AttractionType.diningServiceStyle. These tests pin
// that function and DiningServiceFilter.applied(to:), which is what the
// dining lists use. No venue's stored service type is changed here.

import XCTest
@testable import Parkio

final class DiningServiceFilterTests: XCTestCase {

    /// Spec for every dining service type. A new AttractionType dining case
    /// has to be added here or the coverage test fails, and the switch in
    /// `diningServiceStyle` fails to compile until it is classified.
    private let expectedBucket: [AttractionType: DiningServiceStyle] = [
        .quickService:  .quickService,
        .snackStand:    .quickService,
        .festivalBooth: .quickService,
        .tableService:  .sitDown,
        .lounge:        .sitDown,
    ]

    // MARK: - Mapping

    func testEveryDiningServiceTypeMapsToExactlyOneBucket() {
        let diningTypes = AttractionType.allCases.filter(\.isDining)
        XCTAssertEqual(
            Set(diningTypes),
            Set(expectedBucket.keys),
            "Every dining service type needs exactly one bucket in the spec"
        )

        for type in diningTypes {
            let bucket = type.diningServiceStyle
            XCTAssertNotNil(bucket, "\(type) is dining but maps to no bucket")
            XCTAssertEqual(bucket, expectedBucket[type], "\(type) bucket")
        }
    }

    func testNonDiningTypesHaveNoBucket() {
        let nonDining = AttractionType.allCases.filter { !$0.isDining }
        XCTAssertFalse(nonDining.isEmpty)
        for type in nonDining {
            XCTAssertNil(type.diningServiceStyle, "\(type) should not have a dining bucket")
        }
    }

    func testLoungeMapsToSitDown() {
        XCTAssertEqual(AttractionType.lounge.diningServiceStyle, .sitDown)
    }

    func testSnackStandMapsToQuickService() {
        XCTAssertEqual(AttractionType.snackStand.diningServiceStyle, .quickService)
    }

    func testFestivalBoothMapsToQuickService() {
        // Walk-up counter, same family as a snack stand. No catalog venue
        // uses this case today.
        XCTAssertEqual(AttractionType.festivalBooth.diningServiceStyle, .quickService)
    }

    // MARK: - Filtering

    func testAllReturnsEverything() {
        let venues = sampleVenues
        let filtered = DiningServiceFilter.all.applied(to: venues)
        XCTAssertEqual(filtered.map(\.name), venues.map(\.name))
        XCTAssertEqual(filtered.count, venues.count)
    }

    func testQuickServiceReturnsOnlyItsBucket() {
        let venues = sampleVenues
        let filtered = DiningServiceFilter.quickService.applied(to: venues)
        let expected = venues.filter { $0.type.diningServiceStyle == .quickService }

        XCTAssertFalse(filtered.isEmpty)
        XCTAssertEqual(filtered.map(\.name), expected.map(\.name))
        XCTAssertTrue(filtered.allSatisfy { $0.type.diningServiceStyle == .quickService })
        XCTAssertFalse(filtered.contains { $0.type.diningServiceStyle != .quickService })
        XCTAssertFalse(filtered.contains { $0.type == .ride })
        XCTAssertFalse(filtered.contains { $0.type == .lounge || $0.type == .tableService })
    }

    func testSitDownReturnsOnlyItsBucket() {
        let venues = sampleVenues
        let filtered = DiningServiceFilter.sitDown.applied(to: venues)
        let expected = venues.filter { $0.type.diningServiceStyle == .sitDown }

        XCTAssertFalse(filtered.isEmpty)
        XCTAssertEqual(filtered.map(\.name), expected.map(\.name))
        XCTAssertTrue(filtered.allSatisfy { $0.type.diningServiceStyle == .sitDown })
        XCTAssertFalse(filtered.contains { $0.type.diningServiceStyle != .sitDown })
        XCTAssertFalse(filtered.contains { $0.type == .ride })
        XCTAssertFalse(filtered.contains { $0.type == .quickService || $0.type == .snackStand || $0.type == .festivalBooth })
    }

    func testBucketsPartitionTheCatalog() {
        let dining = RideMasterData.all.filter { $0.type.isDining }
        XCTAssertFalse(dining.isEmpty)

        let all = DiningServiceFilter.all.applied(to: dining)
        let quick = DiningServiceFilter.quickService.applied(to: dining)
        let sitDown = DiningServiceFilter.sitDown.applied(to: dining)

        XCTAssertEqual(all.map(\.stableID), dining.map(\.stableID))
        XCTAssertEqual(quick.count + sitDown.count, dining.count)

        let quickIDs = Set(quick.map(\.stableID))
        let sitDownIDs = Set(sitDown.map(\.stableID))
        XCTAssertTrue(quickIDs.isDisjoint(with: sitDownIDs))
        XCTAssertEqual(quickIDs.union(sitDownIDs), Set(dining.map(\.stableID)))
        XCTAssertTrue(quick.allSatisfy { $0.type.diningServiceStyle == .quickService })
        XCTAssertTrue(sitDown.allSatisfy { $0.type.diningServiceStyle == .sitDown })
    }

    /// Decided by Tom, Nov 28. The Diamond Horseshoe is Sit-down. Plaza Inn
    /// stays Quick service.
    func testDiamondHorseshoeIsSitDown() {
        let diamondHorseshoe = "Magic Kingdom|Liberty Square|The Diamond Horseshoe"
        XCTAssertEqual(RideMasterData.typeByStableID[diamondHorseshoe], .lounge)
        XCTAssertEqual(
            RideMasterData.typeByStableID[diamondHorseshoe]?.diningServiceStyle,
            .sitDown
        )
    }

    /// Decided by Tom, Nov 28. Plaza Inn stays Quick service.
    func testPlazaInnIsQuickService() {
        let plazaInn = "Disneyland|Main Street, U.S.A.|Plaza Inn"
        XCTAssertEqual(RideMasterData.typeByStableID[plazaInn], .quickService)
        XCTAssertEqual(
            RideMasterData.typeByStableID[plazaInn]?.diningServiceStyle,
            .quickService
        )
    }

    // MARK: - Fixtures

    /// One of every dining service type, plus a ride that must survive
    /// `.all` and drop out of either specific bucket.
    private var sampleVenues: [MasterAttraction] {
        [
            MasterAttraction("Counter", park: .epcot, land: "Test", type: .quickService, seed: false),
            MasterAttraction("Cart", park: .epcot, land: "Test", type: .snackStand, seed: false),
            MasterAttraction("Booth", park: .epcot, land: "Test", type: .festivalBooth, seed: false),
            MasterAttraction("Dining Room", park: .epcot, land: "Test", type: .tableService, seed: false),
            MasterAttraction("Bar", park: .epcot, land: "Test", type: .lounge, seed: false),
            MasterAttraction("Coaster", park: .epcot, land: "Test", type: .ride, seed: false),
        ]
    }
}
