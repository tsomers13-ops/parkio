import XCTest
import SwiftData

@testable import Parkio

/// Exact pre-change persistence shape for Ride/RideLog. Keeping the legacy
/// types nested lets this test create a real v1 SQLite store without compiling
/// or launching a second copy of the app.
private enum PreDiningConsumptionSchemaV1: VersionedSchema {
    static var versionIdentifier: Schema.Version { .init(1, 0, 0) }
    static var models: [any PersistentModel.Type] {
        [Ride.self, RideLog.self, WaitTimeCache.self, ParkVisit.self]
    }

    @Model
    final class Ride {
        @Attribute(.unique) var id: String
        var name: String
        var park: String
        var land: String
        var order: Int

        @Relationship(deleteRule: .cascade, inverse: \RideLog.ride)
        var logs: [RideLog] = []

        init(id: String, name: String, park: String, land: String, order: Int) {
            self.id = id
            self.name = name
            self.park = park
            self.land = land
            self.order = order
        }
    }

    @Model
    final class RideLog {
        var date: Date
        var ride: Ride?
        var myDayItemId: String?

        init(date: Date, ride: Ride?, myDayItemId: String? = nil) {
            self.date = date
            self.ride = ride
            self.myDayItemId = myDayItemId
        }
    }
}

@MainActor
final class DiningVisitConsumptionTests: XCTestCase {

    private func makeContext() throws -> ModelContext {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Ride.self,
            RideLog.self,
            configurations: configuration
        )
        return ModelContext(container)
    }

    private func makeRide(
        id: String,
        name: String,
        park: String = "EPCOT",
        land: String = "World Showcase",
        in context: ModelContext
    ) -> Ride {
        let ride = Ride(id: id, name: name, park: park, land: land, order: 0)
        context.insert(ride)
        return ride
    }

    func testExistingStyleLogRemainsValidAndUnspecified() {
        let log = RideLog(date: Date())

        XCTAssertNil(log.diningConsumptionRawValue)
        XCTAssertNil(log.diningConsumption)
    }

    func testFoodDoesNotImplyDrink() {
        let log = RideLog(date: Date(), diningConsumption: .food)

        XCTAssertEqual(log.diningConsumption, .food)
        XCTAssertTrue(log.diningConsumption?.includesFood == true)
        XCTAssertFalse(log.diningConsumption?.includesDrink == true)
    }

    func testFoodAndDrinkRecordsBothWithoutAlcoholAssumption() {
        let log = RideLog(date: Date(), diningConsumption: .foodAndDrink)

        XCTAssertTrue(log.diningConsumption?.includesFood == true)
        XCTAssertTrue(log.diningConsumption?.includesDrink == true)
        XCTAssertEqual(log.diningConsumption?.displayName, "Food & Drink")
    }

    func testRepeatedVisitsKeepIndependentConsumptionSelections() throws {
        let context = try makeContext()
        let ride = makeRide(
            id: "EPCOT|World Showcase|Chefs de France",
            name: "Chefs de France",
            in: context
        )
        let foodVisit = RideLog(
            date: Date(timeIntervalSince1970: 100),
            ride: ride,
            diningConsumption: .food
        )
        let drinkVisit = RideLog(
            date: Date(timeIntervalSince1970: 200),
            ride: ride,
            diningConsumption: .drink
        )
        context.insert(foodVisit)
        context.insert(drinkVisit)
        ride.logs.append(contentsOf: [foodVisit, drinkVisit])
        try context.save()

        let fetched = try context.fetch(FetchDescriptor<RideLog>())
            .sorted { $0.date < $1.date }
        XCTAssertEqual(fetched.map(\.diningConsumption), [.food, .drink])
    }

    func testRestaurantAndSnackStandSharePerVisitConsumptionModel() throws {
        let context = try makeContext()
        let restaurantID = "EPCOT|World Celebration|Connections Eatery"
        let kioskID = "EPCOT|World Showcase|Choza de Margarita"
        let restaurant = makeRide(
            id: restaurantID,
            name: "Connections Eatery",
            land: "World Celebration",
            in: context
        )
        let kiosk = makeRide(id: kioskID, name: "Choza de Margarita", in: context)

        let restaurantVisit = RideLog(ride: restaurant, diningConsumption: .food)
        let kioskVisit = RideLog(ride: kiosk, diningConsumption: .drink)
        context.insert(restaurantVisit)
        context.insert(kioskVisit)
        restaurant.logs.append(restaurantVisit)
        kiosk.logs.append(kioskVisit)

        XCTAssertEqual(RideMasterData.typeByStableID[restaurantID], .quickService)
        XCTAssertEqual(RideMasterData.typeByStableID[kioskID], .snackStand)
        XCTAssertTrue(RideMasterData.typeByStableID[restaurantID]?.isDining == true)
        XCTAssertTrue(RideMasterData.typeByStableID[kioskID]?.isDining == true)
        XCTAssertEqual(restaurant.logs.first?.diningConsumption, .food)
        XCTAssertEqual(kiosk.logs.first?.diningConsumption, .drink)
    }

    func testPreChangeOnDiskStoreMigratesWithoutHistoryLossAndRelaunches() throws {
        let fixtureDirectory = FileManager.default.temporaryDirectory
            .appending(path: "ParkioDiningMigration-\(UUID().uuidString)", directoryHint: .isDirectory)
        try FileManager.default.createDirectory(
            at: fixtureDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: fixtureDirectory) }

        let storeURL = fixtureDirectory.appending(path: "Parkio.store")

        // Build an actual pre-change SQLite store containing both dining and
        // ride history. This schema has no dining-consumption column.
        do {
            let legacySchema = Schema(PreDiningConsumptionSchemaV1.models)
            let legacyConfiguration = ModelConfiguration(
                "PreDiningConsumption",
                schema: legacySchema,
                url: storeURL
            )
            let legacyContainer = try ModelContainer(
                for: legacySchema,
                configurations: [legacyConfiguration]
            )
            let legacyContext = ModelContext(legacyContainer)

            let dining = PreDiningConsumptionSchemaV1.Ride(
                id: "EPCOT|World Celebration|Connections Eatery",
                name: "Connections Eatery",
                park: "EPCOT",
                land: "World Celebration",
                order: 0
            )
            let attraction = PreDiningConsumptionSchemaV1.Ride(
                id: "EPCOT|World Celebration|Spaceship Earth",
                name: "Spaceship Earth",
                park: "EPCOT",
                land: "World Celebration",
                order: 1
            )
            legacyContext.insert(dining)
            legacyContext.insert(attraction)

            let oldLogs = [
                PreDiningConsumptionSchemaV1.RideLog(
                    date: Date(timeIntervalSince1970: 100),
                    ride: dining
                ),
                PreDiningConsumptionSchemaV1.RideLog(
                    date: Date(timeIntervalSince1970: 200),
                    ride: dining,
                    myDayItemId: "legacy-plan-item"
                ),
                PreDiningConsumptionSchemaV1.RideLog(
                    date: Date(timeIntervalSince1970: 300),
                    ride: attraction
                )
            ]
            oldLogs.forEach(legacyContext.insert)
            dining.logs.append(contentsOf: oldLogs.prefix(2))
            attraction.logs.append(oldLogs[2])
            try legacyContext.save()
        }

        let candidateSchema = Schema([
            Ride.self,
            RideLog.self,
            WaitTimeCache.self,
            ParkVisit.self
        ])
        let candidateConfiguration = ModelConfiguration(
            "PreDiningConsumption",
            schema: candidateSchema,
            url: storeURL
        )

        // Open the same file with the candidate model. SwiftData must add the
        // optional column while preserving all legacy relationships and logs.
        do {
            let candidateContainer = try ModelContainer(
                for: candidateSchema,
                configurations: [candidateConfiguration]
            )
            let candidateContext = ModelContext(candidateContainer)
            let migratedLogs = try candidateContext.fetch(FetchDescriptor<RideLog>())
            let migratedRides = try candidateContext.fetch(FetchDescriptor<Ride>())

            XCTAssertEqual(migratedLogs.count, 3)
            XCTAssertEqual(migratedRides.count, 2)
            XCTAssertTrue(migratedLogs.allSatisfy { $0.diningConsumption == nil })
            XCTAssertEqual(migratedRides.reduce(0) { $0 + $1.logs.count }, 3)
            XCTAssertEqual(
                migratedLogs.map { $0.date.timeIntervalSince1970 }.sorted(),
                [100, 200, 300]
            )
            XCTAssertEqual(migratedLogs.compactMap(\.myDayItemId), ["legacy-plan-item"])
            XCTAssertEqual(
                Set(migratedRides.map(\.id)),
                [
                    "EPCOT|World Celebration|Connections Eatery",
                    "EPCOT|World Celebration|Spaceship Earth"
                ]
            )
            XCTAssertEqual(
                migratedLogs.filter { $0.ride?.name == "Connections Eatery" }.count,
                2
            )
            XCTAssertEqual(
                migratedLogs.filter { $0.ride?.name == "Spaceship Earth" }.count,
                1
            )

            guard let dining = migratedRides.first(where: { $0.name == "Connections Eatery" }) else {
                return XCTFail("migrated dining venue is missing")
            }
            for (offset, consumption) in DiningConsumption.allCases.enumerated() {
                let log = RideLog(
                    date: Date(timeIntervalSince1970: TimeInterval(400 + offset)),
                    ride: dining,
                    diningConsumption: consumption
                )
                candidateContext.insert(log)
                dining.logs.append(log)
            }
            try candidateContext.save()
        }

        // A second candidate open simulates relaunch and verifies both the old
        // history and all three newly written choices remain durable.
        do {
            let relaunchedContainer = try ModelContainer(
                for: candidateSchema,
                configurations: [candidateConfiguration]
            )
            let relaunchedContext = ModelContext(relaunchedContainer)
            let relaunchedLogs = try relaunchedContext.fetch(FetchDescriptor<RideLog>())
            let relaunchedRides = try relaunchedContext.fetch(FetchDescriptor<Ride>())

            XCTAssertEqual(relaunchedLogs.count, 6)
            XCTAssertEqual(relaunchedRides.reduce(0) { $0 + $1.logs.count }, 6)
            XCTAssertEqual(relaunchedLogs.filter { $0.diningConsumption == nil }.count, 3)
            XCTAssertEqual(
                relaunchedLogs
                    .filter { $0.diningConsumption == nil }
                    .map { $0.date.timeIntervalSince1970 }
                    .sorted(),
                [100, 200, 300]
            )
            XCTAssertEqual(
                relaunchedLogs.compactMap(\.myDayItemId),
                ["legacy-plan-item"]
            )
            XCTAssertEqual(
                relaunchedLogs.filter { $0.ride?.name == "Connections Eatery" }.count,
                5
            )
            XCTAssertEqual(
                relaunchedLogs.filter { $0.ride?.name == "Spaceship Earth" }.count,
                1
            )
            XCTAssertEqual(
                Set(relaunchedLogs.compactMap(\.diningConsumption)),
                Set(DiningConsumption.allCases)
            )
        }
    }
}
