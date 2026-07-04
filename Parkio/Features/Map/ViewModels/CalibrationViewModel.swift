// CalibrationViewModel.swift — Owns mutable pin positions for live drag calibration.
//
// Isolation: CalibrationViewModel holds a working copy of [ParkMapPin].
// Changes are NOT written back to ParkMapViewModel automatically.
// Call apply(to:) to commit, or copy the output of exportAsSwift() to
// paste directly into ParkMapViewModel.embeddedPins.
//
// Lifecycle (managed by MapTabView):
//   sync(from:)   — call when debug mode is activated or park changes
//   apply(to:)    — call when user taps "Apply" to commit positions

import SwiftUI
import Observation

// MARK: - Undo record

private struct UndoRecord {
    let pinId: String
    let prevX: Double
    let prevY: Double
}

// MARK: - CalibrationViewModel

@MainActor
@Observable
final class CalibrationViewModel {

    // ── Working pin copy ───────────────────────────────────────────────────────
    private(set) var pins: [ParkMapPin] = []

    // ── Selection ─────────────────────────────────────────────────────────────
    private(set) var selectedPinId: String?

    var selectedPin: ParkMapPin? {
        guard let id = selectedPinId else { return nil }
        return pins.first { $0.internalRideId == id }
    }

    // ── Drag state ────────────────────────────────────────────────────────────
    private(set) var draggingPinId: String?
    /// Live normalized x during a drag (drives the crosshair readout).
    private(set) var dragLiveX: Double = 0
    /// Live normalized y during a drag.
    private(set) var dragLiveY: Double = 0

    // Anchor: normalized position at the moment the drag gesture started.
    private var dragAnchorX: Double = 0
    private var dragAnchorY: Double = 0

    // ── Options ───────────────────────────────────────────────────────────────
    var snapToGrid: Bool = true   // snaps mapX/mapY to nearest 0.01

    // ── Undo (single entry — covers the most recent drag) ─────────────────────
    private var undoRecord: UndoRecord?
    var canUndo: Bool { undoRecord != nil }

    // MARK: - Init

    init() {}   // created before parkMapVM exists; call sync(from:) before showing UI

    // MARK: - Sync / Apply

    /// Replaces working pins with the current state of parkMapVM.
    /// Call whenever debug mode is turned on or the active park changes.
    func sync(from vm: ParkMapViewModel) {
        pins          = vm.pins
        selectedPinId = nil
        draggingPinId = nil
        undoRecord    = nil
    }

    /// Writes current working pins back to ParkMapViewModel.
    func apply(to vm: ParkMapViewModel) {
        vm.replacePins(pins)
    }

    // MARK: - Selection

    func select(_ id: String?) {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedPinId = id
        }
    }

    // MARK: - Drag

    func beginDrag(pinId: String) {
        guard let pin = pins.first(where: { $0.internalRideId == pinId }) else { return }
        draggingPinId = pinId
        dragAnchorX   = pin.mapX
        dragAnchorY   = pin.mapY
        dragLiveX     = pin.mapX
        dragLiveY     = pin.mapY
        selectedPinId = pinId
        // Record pre-drag state for undo — overwrites any previous entry
        undoRecord = UndoRecord(pinId: pinId, prevX: pin.mapX, prevY: pin.mapY)
    }

    /// Called on every DragGesture.onChanged event.
    /// translation: value.translation from the gesture (raw screen points)
    /// canvasSize:  size of the map canvas in points
    func updateDrag(translation: CGSize, canvasSize: CGSize) {
        guard let id = draggingPinId,
              canvasSize.width > 0, canvasSize.height > 0 else { return }

        // Compute new normalized position from anchor + delta
        var nx = dragAnchorX + Double(translation.width)  / Double(canvasSize.width)
        var ny = dragAnchorY + Double(translation.height) / Double(canvasSize.height)

        // Clamp to valid map range
        nx = max(0.0, min(1.0, nx))
        ny = max(0.0, min(1.0, ny))

        // Snap to 0.01 grid if enabled
        if snapToGrid {
            nx = (nx * 100).rounded() / 100
            ny = (ny * 100).rounded() / 100
        }

        dragLiveX = nx
        dragLiveY = ny
        applyMove(id: id, x: nx, y: ny)
    }

    func endDrag() {
        draggingPinId = nil
    }

    // MARK: - Undo

    func undo() {
        guard let entry = undoRecord else { return }
        applyMove(id: entry.pinId, x: entry.prevX, y: entry.prevY)
        selectedPinId = entry.pinId
        undoRecord    = nil
    }

    // MARK: - Reset

    /// Resets the selected pin to its original position from the last sync.
    /// Uses the undo record if available; otherwise no-op (sync again to fully reset).
    func resetSelectedPin() {
        guard let entry = undoRecord else { return }
        applyMove(id: entry.pinId, x: entry.prevX, y: entry.prevY)
        undoRecord = nil
    }

    /// Discards all working changes by re-syncing from the source view model.
    /// Requires the caller to pass the current ParkMapViewModel.
    func resetAll(from vm: ParkMapViewModel) {
        sync(from: vm)
    }

    // MARK: - Export

    /// Returns a JSON blob for the current park's pins.
    /// Paste-ready for logging or storage; can also drive a future remote sync.
    func exportAsJSON() -> String {
        struct PinExport: Encodable {
            let internalRideId: String
            let parkId: String
            let displayName: String
            let mapX: Double
            let mapY: Double
            let priority: Int
        }
        let exports = pins.map {
            PinExport(internalRideId: $0.internalRideId,
                      parkId:         $0.parkId,
                      displayName:    $0.displayName,
                      mapX:           (($0.mapX * 1000).rounded() / 1000),
                      mapY:           (($0.mapY * 1000).rounded() / 1000),
                      priority:       $0.priority)
        }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data   = try? encoder.encode(exports),
              let string = String(data: data, encoding: .utf8) else { return "// encoding error" }
        return string
    }

    /// Returns Swift code that can be pasted directly into
    /// ParkMapViewModel.embeddedPins to persist calibrated positions.
    func exportAsSwift() -> String {
        var lines: [String] = [
            "// Calibrated pin positions",
            "// Generated: \(Date().formatted(date: .abbreviated, time: .shortened))",
            "// Paste into ParkMapViewModel.embeddedPins (replace existing entries)",
            "",
        ]
        let grouped = Dictionary(grouping: pins, by: \.parkId)
        for parkId in grouped.keys.sorted() {
            guard let parkPins = grouped[parkId] else { continue }
            lines.append("// MARK: \(parkId)")
            for p in parkPins.sorted(by: { $0.internalRideId < $1.internalRideId }) {
                lines.append(String(format:
                    "pin(\"%@\", \"%@\", \"%@\", x: %.3f, y: %.3f, priority: %d),",
                    p.internalRideId, p.parkId, p.displayName,
                    p.mapX, p.mapY, p.priority
                ))
            }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }

    // MARK: - Private

    private func applyMove(id: String, x: Double, y: Double) {
        guard let idx = pins.firstIndex(where: { $0.internalRideId == id }) else { return }
        let old = pins[idx]
        pins[idx] = ParkMapPin(
            internalRideId: old.internalRideId,
            parkId:         old.parkId,
            displayName:    old.displayName,
            mapX:           x,
            mapY:           y,
            visualOffsetX:  old.visualOffsetX,
            visualOffsetY:  old.visualOffsetY,
            labelOffsetX:   old.labelOffsetX,
            labelOffsetY:   old.labelOffsetY,
            anchorType:     old.anchorType,
            priority:       old.priority
        )
    }
}
