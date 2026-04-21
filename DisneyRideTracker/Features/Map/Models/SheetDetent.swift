// SheetDetent.swift — Bottom-sheet position states for the map ride detail sheet.
//
// Three detents:
//   .collapsed — slim bar (drag handle + context label). Always visible.
//   .peek      — ~28% of screen. Ride summary + one primary CTA.
//   .full      — ~72% of screen. Complete ride card with all actions.
//
// Height calculation uses the container height passed in from GeometryReader
// so the sheet works correctly across all iPhone sizes and orientations.
//
// Navigation rules (enforced by MapViewModel):
//   • Tap a pin           → .peek
//   • Tap map background  → .collapsed  (selection cleared)
//   • Drag up             → .peek → .full
//   • Drag down           → .full → .peek → .collapsed
//   • Drag to .collapsed  → selection is NOT cleared (user can re-expand)

import CoreGraphics

// MARK: - SheetDetent

enum SheetDetent: Equatable, CaseIterable {
    case collapsed
    case peek
    case full

    // MARK: Heights

    /// Absolute point height for this detent given a container height.
    func height(for containerHeight: CGFloat) -> CGFloat {
        switch self {
        case .collapsed: return 72              // drag handle + label
        case .peek:      return max(200, containerHeight * 0.28)
        case .full:      return containerHeight * 0.72
        }
    }

    // MARK: Navigation helpers

    /// One step up the detent ladder (collapsed → peek → full).
    var expanded: SheetDetent {
        switch self {
        case .collapsed: return .peek
        case .peek:      return .full
        case .full:      return .full
        }
    }

    /// One step down the detent ladder (full → peek → collapsed).
    var reduced: SheetDetent {
        switch self {
        case .full:      return .peek
        case .peek:      return .collapsed
        case .collapsed: return .collapsed
        }
    }

    // MARK: Snap logic

    /// Returns the detent whose height is closest to the provided height.
    /// Used after a drag gesture ends without enough velocity to step one level.
    func nearest(to height: CGFloat, containerHeight: CGFloat) -> SheetDetent {
        SheetDetent.allCases.min(by: {
            abs($0.height(for: containerHeight) - height) <
            abs($1.height(for: containerHeight) - height)
        }) ?? .collapsed
    }

    // MARK: Convenience flags

    var isExpanded: Bool  { self == .full }
    var showsContent: Bool { self != .collapsed }
}
