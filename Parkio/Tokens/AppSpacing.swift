// AppSpacing.swift — Design token layer (Phase 2)
// Spacing, radius, motion, and haptic constants.

import SwiftUI

// MARK: - Spacing

enum AppSpacing {
    static let xxs: CGFloat = 2
    static let xs:  CGFloat = 4
    static let sm:  CGFloat = 8
    static let md:  CGFloat = 12
    static let lg:  CGFloat = 16
    static let xl:  CGFloat = 24
    static let xxl: CGFloat = 32
    static let xxxl: CGFloat = 48

    /// Standard inner padding for card surfaces.
    static let cardPadding: CGFloat = 16
    /// Horizontal screen edge inset.
    static let screenEdge: CGFloat = 16
    /// Vertical gap between sections.
    static let sectionGap: CGFloat = 24
}

// MARK: - Radius

enum AppRadius {
    static let sm:   CGFloat = 8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 24
    static let full: CGFloat = 999
}

// MARK: - Motion

enum AppMotion {
    /// Snappy micro-interaction (button press, toggle).
    static let quick    = Animation.easeOut(duration: 0.15)
    /// Standard transition (sheet, card appear).
    static let standard = Animation.easeInOut(duration: 0.25)
    /// Slower emphasis (onboarding, celebration).
    static let emphasis = Animation.spring(response: 0.45, dampingFraction: 0.7)
    /// Spring for FAB / sheet entrance.
    static let spring   = Animation.spring(response: 0.35, dampingFraction: 0.75)
}

// MARK: - Haptics

enum AppHaptic {
    static func light()    { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
    static func medium()   { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
    static func heavy()    { UIImpactFeedbackGenerator(style: .heavy).impactOccurred() }
    static func success()  { UINotificationFeedbackGenerator().notificationOccurred(.success) }
    static func warning()  { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    static func error()    { UINotificationFeedbackGenerator().notificationOccurred(.error) }
    static func selection() { UISelectionFeedbackGenerator().selectionChanged() }
}
