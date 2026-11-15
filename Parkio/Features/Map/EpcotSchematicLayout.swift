// EpcotSchematicLayout.swift — EPCOT canvas geometry derived only from
// attraction coordinates that already exist in the app.
//
// World Nature, World Discovery, and World Celebration are the bounding
// boxes of those lands' projected points. World Showcase is the ring of
// those points around their centroid: the lagoon is the open middle, and
// each tight cluster of points becomes one pavilion block. A point that
// sits far from the rest of its land (Journey Into Imagination's stored
// coordinate does) still keeps its own pin; it is left out of the land
// block so one outlier does not stretch the block across the park.

import CoreGraphics
import Foundation

struct EpcotAttractionSample: Equatable {
    var id: String
    var name: String
    var land: String
    var latitude: Double
    var longitude: Double
    var priority: Int
}

struct EpcotSchematicLayout: Equatable {

    struct Pin: Equatable {
        var id: String
        var name: String
        var x: Double
        var y: Double
        var priority: Int
    }

    struct Block: Equatable {
        var id: String
        var label: String?
        var x: Double
        var y: Double
        var width: Double
        var height: Double
    }

    var pins: [Pin]
    var landBlocks: [Block]
    var pavilionBlocks: [Block]
    var lagoon: Block?
    var spaceshipEarth: Block?

    static let worldShowcase = "World Showcase"
    static let spaceshipEarthName = "Spaceship Earth"

    static func make(
        from samples: [EpcotAttractionSample],
        bounds: GeoBounds = MapSchematicProjection.epcotBounds
    ) -> EpcotSchematicLayout {
        let projected: [(EpcotAttractionSample, CGPoint)] = samples.compactMap { sample in
            guard let point = MapSchematicProjection.normalize(
                latitude: sample.latitude,
                longitude: sample.longitude,
                bounds: bounds
            ) else { return nil }
            return (sample, point)
        }

        let pins = projected.map { sample, point in
            Pin(id: sample.id, name: sample.name, x: point.x, y: point.y, priority: sample.priority)
        }

        let showcase = projected.filter { $0.0.land == worldShowcase }.map(\.1)
        let lagoon = lagoonBlock(around: showcase)
        let pavilions = pavilionBlocks(around: showcase)

        var landBlocks: [Block] = []
        let lands = Dictionary(grouping: projected.filter { $0.0.land != worldShowcase }, by: { $0.0.land })
        for land in lands.keys.sorted() {
            let points = lands[land, default: []].map(\.1)
            guard let box = boundingBlock(id: "ep-land-\(slug(land))", label: land, points: inliers(points), pad: 0.03) else {
                continue
            }
            landBlocks.append(box)
        }

        let spaceship = projected.first { $0.0.name == spaceshipEarthName }?.1
        let landmark = spaceship.map { point in
            clampedBlock(
                id: "ep-spaceship-earth",
                label: spaceshipEarthName,
                center: point,
                width: 0.11,
                height: 0.09
            )
        }

        return EpcotSchematicLayout(
            pins: pins,
            landBlocks: landBlocks,
            pavilionBlocks: pavilions,
            lagoon: lagoon,
            spaceshipEarth: landmark
        )
    }

    // MARK: - Lagoon and pavilions

    private static func lagoonBlock(around points: [CGPoint]) -> Block? {
        guard points.count >= 3 else { return nil }
        let center = centroid(points)
        let distances = points.map { hypot($0.x - center.x, $0.y - center.y) }.sorted()
        let median = distances[distances.count / 2]
        let radius = max(0.04, median * 0.45)
        return clampedBlock(
            id: "ep-lagoon",
            label: worldShowcase,
            center: center,
            width: radius * 2,
            height: radius * 2
        )
    }

    /// Attractions within 0.05 of a running centroid share one pavilion block.
    private static func pavilionBlocks(around points: [CGPoint]) -> [Block] {
        var clusters: [[CGPoint]] = []
        for point in points.sorted(by: { $0.x < $1.x }) {
            if let index = clusters.indices.first(where: { index in
                let center = centroid(clusters[index])
                return hypot(point.x - center.x, point.y - center.y) < 0.05
            }) {
                clusters[index].append(point)
            } else {
                clusters.append([point])
            }
        }
        return clusters.enumerated().map { index, cluster in
            clampedBlock(
                id: "ep-pavilion-\(index)",
                label: nil,
                center: centroid(cluster),
                width: 0.055,
                height: 0.042
            )
        }
    }

    // MARK: - Geometry helpers

    /// Drops a point that sits much farther from the land's median than the
    /// rest, so one stored coordinate cannot stretch the land block.
    static func inliers(_ points: [CGPoint]) -> [CGPoint] {
        guard points.count >= 3 else { return points }
        let xs = points.map(\.x).sorted()
        let ys = points.map(\.y).sorted()
        let center = CGPoint(x: xs[xs.count / 2], y: ys[ys.count / 2])
        let distances = points.map { hypot($0.x - center.x, $0.y - center.y) }.sorted()
        let median = distances[distances.count / 2]
        guard median > 0.000_1 else { return points }
        let kept = points.filter { hypot($0.x - center.x, $0.y - center.y) <= median * 2.5 }
        return kept.isEmpty ? points : kept
    }

    private static func boundingBlock(
        id: String,
        label: String?,
        points: [CGPoint],
        pad: Double
    ) -> Block? {
        guard let first = points.first else { return nil }
        var minX = first.x, maxX = first.x, minY = first.y, maxY = first.y
        for point in points.dropFirst() {
            minX = min(minX, point.x); maxX = max(maxX, point.x)
            minY = min(minY, point.y); maxY = max(maxY, point.y)
        }
        return clampedRect(
            id: id,
            label: label,
            x: minX - pad,
            y: minY - pad,
            width: (maxX - minX) + pad * 2,
            height: (maxY - minY) + pad * 2
        )
    }

    private static func clampedBlock(
        id: String,
        label: String?,
        center: CGPoint,
        width: Double,
        height: Double
    ) -> Block {
        clampedRect(
            id: id,
            label: label,
            x: center.x - width / 2,
            y: center.y - height / 2,
            width: width,
            height: height
        )
    }

    private static func clampedRect(
        id: String,
        label: String?,
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> Block {
        let minEdge = 0.02
        let maxEdge = 0.98
        let clampedX = min(max(x, minEdge), maxEdge)
        let clampedY = min(max(y, minEdge), maxEdge)
        let clampedW = min(width, maxEdge - clampedX)
        let clampedH = min(height, maxEdge - clampedY)
        return Block(
            id: id,
            label: label,
            x: clampedX,
            y: clampedY,
            width: max(clampedW, 0.02),
            height: max(clampedH, 0.02)
        )
    }

    private static func centroid(_ points: [CGPoint]) -> CGPoint {
        let count = Double(points.count)
        let x = points.reduce(0.0) { $0 + $1.x } / count
        let y = points.reduce(0.0) { $0 + $1.y } / count
        return CGPoint(x: x, y: y)
    }

    private static func slug(_ land: String) -> String {
        land.lowercased().replacingOccurrences(of: " ", with: "-")
    }
}
