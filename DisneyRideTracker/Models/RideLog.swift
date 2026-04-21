//
//  RideLog.swift
//  DisneyRideTracker
//

import Foundation
import SwiftData

@Model
final class RideLog {
    var date: Date
    var ride: Ride?

    init(date: Date = Date(), ride: Ride? = nil) {
        self.date = date
        self.ride = ride
    }
}
