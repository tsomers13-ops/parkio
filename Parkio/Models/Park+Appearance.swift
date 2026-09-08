//
//  Park+Appearance.swift
//  Parkio
//
//  Presentation-only members of `Park`, split out of Park.swift so the core
//  model stays Foundation-only and can be compiled by the macOS content
//  exporter (Tools/DiningExporter). App behavior is unchanged.
//

import SwiftUI

extension Park {
    /// Each park gets its own accent color — design system §3 (Phase 2).
    var accentColor: Color {
        switch self {
        case .magicKingdom:        return Color(hex: "#1F4FFF")  // Royal blue
        case .epcot:               return Color(hex: "#0EA5E9")  // Sky blue
        case .hollywoodStudios:    return Color(hex: "#E63946")  // Studio red
        case .animalKingdom:       return Color(hex: "#2D6A4F")  // Forest green
        case .disneyland:          return Color(hex: "#7C3AED")  // Main Street violet
        case .californiaAdventure: return Color(hex: "#F15025")  // Pixar orange
        }
    }

    /// Soft tinted background for park-contextual surfaces.
    var accentBackground: Color {
        switch self {
        case .magicKingdom:        return Color(hex: "#EEF2FF")
        case .epcot:               return Color(hex: "#E0F5FF")
        case .hollywoodStudios:    return Color(hex: "#FEE8E9")
        case .animalKingdom:       return Color(hex: "#E8F5EE")
        case .disneyland:          return Color(hex: "#F0EEFF")
        case .californiaAdventure: return Color(hex: "#FFF0EB")
        }
    }
}
