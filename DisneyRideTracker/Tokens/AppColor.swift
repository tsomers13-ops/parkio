// AppColor.swift — Design token layer (Phase 2)
// All hex values live here. No hex anywhere else in the project.

import SwiftUI

// MARK: - Hex initialiser

extension Color {
    init(hex: String) {
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
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - Token namespace

enum AppColor {
    // Brand
    static let brandPrimary  = Color(hex: "#1F4FFF")
    static let brandGold     = Color(hex: "#FFC83D")   // decorative only
    static let brandGoldDeep = Color(hex: "#B8860B")   // AA-compliant text

    // Surfaces
    static let background    = Color(hex: "#FFF8E7")   // warm cream
    static let card          = Color.white
    static let skeleton      = Color(hex: "#E5E5EA")

    // Text
    static let textPrimary   = Color(hex: "#1C1C1E")
    static let textSecondary = Color(hex: "#6E6E73")
    static let textTertiary  = Color(hex: "#AEAEB2")

    // Status
    static let success       = Color(hex: "#34C759")
    static let warning       = Color(hex: "#FF9F0A")   // amber — offline/stale banners
    static let error         = Color(hex: "#FF453A")   // semantic alias
    static let alert         = Color(hex: "#FF453A")   // legacy alias → prefer error
    static let waitOrange    = Color(hex: "#FF8A3D")

    // Wait band colours (matches Phase 2 §10)
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
