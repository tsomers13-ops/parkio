//
//  CoordinateSource.swift
//  dining-export
//
//  Reads the app's authoritative MapCoordinates.json and indexes it by the
//  same stableID the app uses. Coordinates are never duplicated in exporter
//  source — this file only decodes and indexes.
//

import Foundation

struct RawCoordinateEntry: Decodable {
    let id: String
    let parkId: String
    let lat: Double
    let lon: Double
    let category: String?
}

private struct DynamicKey: CodingKey {
    var stringValue: String
    var intValue: Int? { nil }
    init?(stringValue: String) { self.stringValue = stringValue }
    init?(intValue: Int) { nil }
}

enum CoordinateSource {

    static let relativePath = "Parkio/Features/Map/Resources/MapCoordinates.json"

    /// Indexes every coordinate entry by stableID.
    /// Returns the index plus any stableIDs that appear more than once.
    static func load(repo: URL) throws -> (index: [String: RawCoordinateEntry], duplicates: [String]) {
        let url = repo.appendingPathComponent(relativePath)
        guard let data = try? Data(contentsOf: url) else {
            throw ExportError.io("could not read \(relativePath)")
        }

        // Top level is parkId -> [entry], alongside a "_comment" array that is
        // skipped because it does not decode as [RawCoordinateEntry].
        let decoder = JSONDecoder()
        let container = try decoder.decode(CoordinateFile.self, from: data)

        var index: [String: RawCoordinateEntry] = [:]
        var duplicates: [String] = []
        for entry in container.entries {
            if index[entry.id] != nil { duplicates.append(entry.id) }
            index[entry.id] = entry
        }
        return (index, duplicates.sorted())
    }

    private struct CoordinateFile: Decodable {
        let entries: [RawCoordinateEntry]
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: DynamicKey.self)
            var collected: [RawCoordinateEntry] = []
            for key in container.allKeys.sorted(by: { $0.stringValue < $1.stringValue }) {
                if let group = try? container.decode([RawCoordinateEntry].self, forKey: key) {
                    collected.append(contentsOf: group)
                }
            }
            entries = collected
        }
    }
}
