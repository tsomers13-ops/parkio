//
//  Ride.swift
//  DisneyRideTracker
//

import Foundation
import SwiftData

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

    var isRidden: Bool {
        !logs.isEmpty
    }

    var rideCount: Int {
        logs.count
    }

    var mostRecentDate: Date? {
        logs.map(\.date).max()
    }

    var sortedLogs: [RideLog] {
        logs.sorted { $0.date > $1.date }
    }
}
