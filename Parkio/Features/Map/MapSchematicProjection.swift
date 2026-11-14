// MapSchematicProjection.swift — Linear north-up projection of a GPS
// coordinate into the custom map canvas.
//
// The EPCOT bounds are the validation window already recorded in
// MapCoordinates.json. Nothing here invents a latitude or longitude.
// `canvasInset` keeps every projected point inside the region that the
// canvas default viewport still shows, so a point on the park boundary
// is not clipped at the default fit.

import CoreGraphics

struct GeoBounds: Equatable {
    var latitudeMin: Double
    var latitudeMax: Double
    var longitudeMin: Double
    var longitudeMax: Double
}

enum MapSchematicProjection {

    /// EPCOT window from the "Park bounds used for validation" note in
    /// Parkio/Features/Map/Resources/MapCoordinates.json.
    static let epcotBounds = GeoBounds(
        latitudeMin: 28.3670,
        latitudeMax: 28.3765,
        longitudeMin: -81.5545,
        longitudeMax: -81.5450
    )

    /// Fraction of the canvas kept clear on every edge.
    static let canvasInset: Double = 0.08

    /// North is up. x grows east, y grows south, both in 0...1 after inset.
    static func normalize(
        latitude: Double,
        longitude: Double,
        bounds: GeoBounds,
        inset: Double = canvasInset
    ) -> CGPoint {
        let width = bounds.longitudeMax - bounds.longitudeMin
        let height = bounds.latitudeMax - bounds.latitudeMin
        guard width != 0, height != 0 else { return CGPoint(x: 0.5, y: 0.5) }
        let rawX = (longitude - bounds.longitudeMin) / width
        let rawY = (bounds.latitudeMax - latitude) / height
        let span = 1 - (2 * inset)
        return CGPoint(x: inset + rawX * span, y: inset + rawY * span)
    }
}
