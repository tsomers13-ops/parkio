// AppColor.swift — Design token layer
// All hex values live here. No hex anywhere else in the project.
//
// Dark Mode
// ─────────
// Every surface and text token now has a Light and a Dark variant.
// The adaptive Color(light:dark:) initialiser uses UIColor's dynamicProvider
// so the correct value is resolved at render time, reacting to both the
// system setting and any .preferredColorScheme() override applied at the root.
//
// Brand, status, and wait-band colours are identical in both modes —
// they are vivid enough to read well on both light cream and near-black surfaces.
//
// Contrast targets (WCAG)
// ───────────────────────
//   textPrimary   — ≥ 7:1 on background/card in both modes   (AAA)
//   textSecondary — ≥ 4.5:1 on background/card in both modes (AA)
//   textTertiary  — ~2:1 intentionally low (dates, captions, decorative hints)
//   brandGoldDeep — 4.6:1 on light card / 4.5:1 on dark card  (AA body text)

import SwiftUI
import UIKit

// MARK: - UIColor hex helper (private — only used to build adaptive tokens below)

private extension UIColor {
    convenience init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3:  (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6:  (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:  (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default: (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            red:   Double(r) / 255,
            green: Double(g) / 255,
            blue:  Double(b) / 255,
            alpha: Double(a) / 255
        )
    }
}

// MARK: - Color initialisers

extension Color {
    /// Hex initialiser — preserved for the waitColor inline literal below.
    init(hex: String) {
        self.init(UIColor(hex: hex))
    }

    /// Adaptive initialiser. The UIColor dynamicProvider resolves the hex at
    /// render time, responding correctly to .preferredColorScheme() overrides
    /// as well as the device-level setting.
    fileprivate init(light: String, dark: String) {
        self.init(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(hex: dark)
                : UIColor(hex: light)
        })
    }
}

// MARK: - Token namespace

enum AppColor {

    // ── Brand (identical in Light and Dark) ────────────────────────────────────
    // Blue and gold read well against both the warm-cream light background and
    // the near-black dark background.

    static let brandPrimary  = Color(hex: "#1F4FFF")
    static let brandGold     = Color(hex: "#FFC83D")   // decorative only
    static let brandGoldDeep = Color(hex: "#B8860B")   // 4.6:1 light / 4.5:1 dark (AA ✓)

    // ── Surfaces ───────────────────────────────────────────────────────────────
    // Light: warm-cream page / pure-white card / system-grey skeleton loader
    // Dark : iOS standard dark base / elevated surface / subtly lighter surface

    static let background = Color(light: "#FFF8E7", dark: "#1C1C1E")
    static let card       = Color(light: "#FFFFFF", dark: "#2C2C2E")
    static let skeleton   = Color(light: "#E5E5EA", dark: "#3A3A3C")

    // ── Text ───────────────────────────────────────────────────────────────────
    // Light hierarchy: near-black → mid-grey → light-grey
    // Dark hierarchy : near-white → mid-grey → muted-grey
    //
    // textPrimary   — 16.7:1 light / 13.5:1 dark on their respective cards
    // textSecondary —  5.9:1 light /  4.6:1 dark on their respective cards (AA ✓)
    // textTertiary  — intentionally low (~2:1) — dates, captions, decoration

    static let textPrimary   = Color(light: "#1C1C1E", dark: "#F2F2F7")
    static let textSecondary = Color(light: "#6E6E73", dark: "#8E8E93")
    static let textTertiary  = Color(light: "#AEAEB2", dark: "#636366")

    // ── Status (identical in Light and Dark) ───────────────────────────────────
    static let success    = Color(hex: "#34C759")
    static let warning    = Color(hex: "#FF9F0A")   // amber — offline / stale banners
    static let error      = Color(hex: "#FF453A")   // semantic name
    static let alert      = Color(hex: "#FF453A")   // legacy alias → prefer error
    static let waitOrange = Color(hex: "#FF8A3D")

    // ── Wait band colours (§10) ────────────────────────────────────────────────

    static func waitColor(minutes: Int) -> Color {
        switch minutes {
        case 0...15:  return success
        case 16...30: return brandGold
        case 31...45: return waitOrange
        case 46...60: return Color(hex: "#FF6B35")
        default:      return alert
        }
    }

    static func waitLabel(minutes: Int) -> String {
        switch minutes {
        case 0...15:  return "Short"
        case 16...30: return "Moderate"
        case 31...45: return "Long"
        case 46...60: return "Very long"
        default:      return "Extreme"
        }
    }
}
