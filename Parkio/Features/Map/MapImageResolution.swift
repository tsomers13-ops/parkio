// MapImageResolution.swift — Pure decision logic for which map image asset to use.
//
// Decoupled from UIImage/UIKit (via the injected `assetExists` closure) so it
// is directly unit testable via `swift test` without a UIKit-linked target.
//
// Resolution order (first match wins):
//   1. "<parkId>_map"       — production asset. Always preferred when present,
//                             in BOTH debug and release — a park's real map art
//                             must never be silently swapped for placeholder art.
//   2. "<parkId>_map_mock"  — DEBUG-only fallback, used only when no production
//                             asset exists yet (lets other parks be previewed
//                             with placeholder art before real art ships).
enum MapImageResolution {
    static func imageName(
        forParkId parkId: String,
        isDebugBuild: Bool,
        assetExists: (String) -> Bool
    ) -> String {
        let base = parkId.replacingOccurrences(of: "-", with: "_") + "_map"
        if assetExists(base) { return base }
        if isDebugBuild, assetExists(base + "_mock") { return base + "_mock" }
        return base
    }
}
