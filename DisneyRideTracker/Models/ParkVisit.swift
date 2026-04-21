//
//  ParkVisit.swift
//  DisneyRideTracker
//

import Foundation
import SwiftData

@Model
final class ParkVisit {
    @Attribute(.unique) var id: UUID
    var parkId: String
    var parkName: String
    var visitDate: Date
    var visitYear: Int

    init(
        id: UUID = UUID(),
        parkId: String,
        parkName: String,
        visitDate: Date,
        calendar: Calendar = .current
    ) {
        self.id = id
        self.parkId = parkId
        self.parkName = parkName
        self.visitDate = visitDate
        self.visitYear = calendar.component(.year, from: visitDate)
    }
}
