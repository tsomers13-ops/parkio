// ParkMapViewModel.swift — Pin position management for the custom map canvas.
//
// Responsibilities:
//   • Load normalized (0–1) ParkMapPin data for the active park.
//   • Expose debugMode toggle and out-of-bounds detection for calibration.
//   • Provide the park map image asset name.
//
// Selection and live wait enrichment remain in MapViewModel so the
// bottom sheet, filter chips, and WaitTimeViewModel wiring keep working.
//
// Image naming convention:
//   Add an asset named "<parkId-with-underscores>_map" to Assets.xcassets.
//   Example: "magic_kingdom_map", "disneyland_map".
//   If the asset is missing, ParkMapCanvasView shows a solid fallback.

import SwiftUI
import UIKit
import Observation

@MainActor
@Observable
final class ParkMapViewModel {

    // ── Active park ────────────────────────────────────────────────────────────
    var parkId: String {
        didSet {
            guard parkId != oldValue else { return }
            loadPins()
        }
    }

    // ── Pin data ───────────────────────────────────────────────────────────────
    private(set) var pins: [ParkMapPin] = []

    // ── Debug / calibration ───────────────────────────────────────────────────
    var debugMode: Bool = false

    // MARK: - Derived

    var outOfBoundsPins: [ParkMapPin] {
        pins.filter { $0.isOutOfBounds }
    }

    /// Asset name for the park map background image.
    ///
    /// Resolution order (first match wins) — see MapImageResolution for the
    /// pure, unit-tested decision logic this wraps:
    ///   1. "<parkId>_map"       — production asset. Always preferred when
    ///                             present, in both DEBUG and release.
    ///   2. "<parkId>_map_mock"  — DEBUG-only fallback for parks with no
    ///                             production art yet.
    ///
    /// Example: "disneyland" → "disneyland_map" if it exists, else (DEBUG
    /// only) "disneyland_map_mock".
    /// Add assets to Assets.xcassets using these names.
    var mapImageName: String {
        #if DEBUG
        let isDebugBuild = true
        #else
        let isDebugBuild = false
        #endif
        return MapImageResolution.imageName(forParkId: parkId, isDebugBuild: isDebugBuild) {
            UIImage(named: $0) != nil
        }
    }

    /// True when a map image asset actually exists for the current park.
    /// Use this to decide whether to show a placeholder background.
    var hasMapImage: Bool {
        UIImage(named: mapImageName) != nil
    }

    // MARK: - Init

    init(parkId: String) {
        self.parkId = parkId
        loadPins()
    }

    // MARK: - Actions

    func loadPins() {
        pins = ParkMapPinData.embeddedPins[parkId] ?? []
    }

    func pin(forRideId rideId: String) -> ParkMapPin? {
        pins.first { $0.internalRideId == rideId }
    }

    /// Called by CalibrationViewModel.apply(to:) to commit calibrated positions.
    func replacePins(_ newPins: [ParkMapPin]) {
        pins = newPins
    }
}

// MARK: - Preview stub

extension ParkMapViewModel {
    /// Quick stub for Xcode previews — includes one intentionally out-of-bounds pin.
    static func previewStub(parkId: String = "disneyland") -> ParkMapViewModel {
        let vm = ParkMapViewModel(parkId: parkId)
        return vm
    }
}
