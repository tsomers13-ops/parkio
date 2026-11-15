// MapSchematicProjection.swift — Linear projection of a GPS coordinate
// into the custom map canvas.
//
// `parkBounds` is the only Swift copy of the validation windows. The DEBUG
// check in MapCoordinateService reads this table; it does not keep its own.
// Nothing here invents a latitude or longitude.
//
// `normalize` returns nil when the window is degenerate or the coordinate
// falls outside it, so a caller hides the pin instead of dropping it at
// the canvas center.
//
// The default projection is north-up: higher latitude is smaller y, and
// higher longitude is larger x. EPCOT's illustration is rotated 180° from
// that, with the entrance at the bottom, so callers that place a point on
// the artwork pass `.northDown`.

import CoreGraphics

struct GeoBounds: Equatable {
    var latitudeMin: Double
    var latitudeMax: Double
    var longitudeMin: Double
    var longitudeMax: Double

    func contains(latitude: Double, longitude: Double) -> Bool {
        latitude >= latitudeMin && latitude <= latitudeMax
            && longitude >= longitudeMin && longitude <= longitudeMax
    }
}

enum MapArtOrientation: Equatable {
    /// Higher latitude is smaller y. Higher longitude is larger x.
    case northUp
    /// Higher latitude is larger y. Higher longitude is smaller x.
    /// Matches the EPCOT illustration, where the entrance is at the bottom.
    case northDown
}

enum MapSchematicProjection {

    /// Validation windows shared with MapCoordinateService.
    /// Hollywood Studios maxLat is 28.3615 so the verified Fantasmic!
    /// amphitheater coordinate (28.3612252) stays inside the window.
    static let parkBounds: [String: GeoBounds] = [
        "magic-kingdom": GeoBounds(
            latitudeMin: 28.4160, latitudeMax: 28.4230,
            longitudeMin: -81.5865, longitudeMax: -81.5750),
        "epcot": GeoBounds(
            latitudeMin: 28.3670, latitudeMax: 28.3765,
            longitudeMin: -81.5545, longitudeMax: -81.5450),
        "hollywood-studios": GeoBounds(
            latitudeMin: 28.3525, latitudeMax: 28.3615,
            longitudeMin: -81.5650, longitudeMax: -81.5560),
        "animal-kingdom": GeoBounds(
            latitudeMin: 28.3530, latitudeMax: 28.3630,
            longitudeMin: -81.5945, longitudeMax: -81.5860),
        "disneyland": GeoBounds(
            latitudeMin: 33.8090, latitudeMax: 33.8165,
            longitudeMin: -117.9240, longitudeMax: -117.9160),
        "california-adventure": GeoBounds(
            latitudeMin: 33.8040, latitudeMax: 33.8095,
            longitudeMin: -117.9240, longitudeMax: -117.9160),
    ]

    static var epcotBounds: GeoBounds { parkBounds["epcot"]! }

    /// Fraction of the canvas kept clear on every edge.
    static let canvasInset: Double = 0.08

    /// Projects one coordinate into 0...1 canvas space.
    /// Nil when `bounds` has no area, or the coordinate is outside the window.
    static func normalize(
        latitude: Double,
        longitude: Double,
        bounds: GeoBounds,
        inset: Double = canvasInset,
        orientation: MapArtOrientation = .northUp
    ) -> CGPoint? {
        let width = bounds.longitudeMax - bounds.longitudeMin
        let height = bounds.latitudeMax - bounds.latitudeMin
        guard width > 0, height > 0 else { return nil }
        let rawX = (longitude - bounds.longitudeMin) / width
        let rawY = (bounds.latitudeMax - latitude) / height
        guard rawX >= 0, rawX <= 1, rawY >= 0, rawY <= 1 else { return nil }
        let orientedX = orientation == .northDown ? 1 - rawX : rawX
        let orientedY = orientation == .northDown ? 1 - rawY : rawY
        let span = 1 - (2 * inset)
        return CGPoint(
            x: inset + orientedX * span,
            y: inset + orientedY * span
        )
    }
}
