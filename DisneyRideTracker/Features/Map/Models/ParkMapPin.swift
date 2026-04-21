// ParkMapPin.swift — Normalized (0–1) pin position for the custom map canvas.
//
// mapX / mapY are fractions of the map image dimensions, top-left origin:
//   screenX = geometry.size.width  * mapX + visualOffsetX
//   screenY = geometry.size.height * mapY + visualOffsetY
//
// visualOffsetX/Y: fine-tune the pin graphic's screen position (points).
// labelOffsetX/Y:  fine-tune the label relative to the pin graphic (points).
// anchorType:      which part of the pin graphic touches the coordinate.

import CoreGraphics

// MARK: - Anchor type

/// Determines which part of the pin graphic is pinned to the computed coordinate.
/// The canvas uses this to shift the SwiftUI view so the correct edge aligns.
enum PinAnchorType: String, Codable, CaseIterable {
    case bottomCenter   // standard map pin — tip points at location (default)
    case topCenter
    case leftCenter
    case rightCenter
    case center
}

// MARK: - ParkMapPin

/// A single ride's position on the custom park map image.
/// All spatial data is normalized so the layout adapts to any screen size.
struct ParkMapPin: Identifiable, Codable {

    // ── Identity ───────────────────────────────────────────────────────────────
    /// Matches `MapRideAnnotation.id` (e.g. "mk|space-mountain").
    let internalRideId: String

    let parkId: String
    let displayName: String

    // ── Normalized position (0.0 – 1.0 relative to map image) ─────────────────
    let mapX: Double
    let mapY: Double

    // ── Fine-tune offsets (screen points, applied after coord conversion) ──────
    let visualOffsetX: CGFloat
    let visualOffsetY: CGFloat
    let labelOffsetX: CGFloat
    let labelOffsetY: CGFloat

    let anchorType: PinAnchorType

    /// 1 = headliner (always shown), 2 = secondary, 3 = low-priority / dense area.
    let priority: Int

    var id: String { internalRideId }

    // MARK: - Helpers

    /// True when this pin falls outside the 0–1 bounds of the map image.
    var isOutOfBounds: Bool {
        mapX < 0.0 || mapX > 1.0 || mapY < 0.0 || mapY > 1.0
    }

    /// Resolves the screen position of this pin's anchor within a given canvas size.
    /// Applies visualOffsets but not anchorType adjustment — the caller handles that
    /// by offsetting the rendered view based on its actual size.
    func canvasPoint(in size: CGSize) -> CGPoint {
        CGPoint(
            x: size.width  * mapX + visualOffsetX,
            y: size.height * mapY + visualOffsetY
        )
    }
}
