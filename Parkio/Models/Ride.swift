//
//  Ride.swift
//  Parkio
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

    /// Ensures at least one visit is recorded, without inflating an existing
    /// count. The single authoritative "has this been visited" write path —
    /// every caller that needs to guarantee a visit exists (rather than log a
    /// specific date) should call this instead of inserting a RideLog itself.
    ///
    /// No-ops when a visit already exists, so calling this on every
    /// Community Rating submission (create AND update) never double-counts.
    func logVisitIfNeeded(in context: ModelContext) {
        guard logs.isEmpty else { return }
        let log = RideLog(date: Date(), ride: self)
        context.insert(log)
        logs.append(log)
        try? context.save()
    }
}
