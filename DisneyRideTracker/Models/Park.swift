//
//  Park.swift
//  DisneyRideTracker
//

import SwiftUI

enum Park: String, CaseIterable, Identifiable {
    // Walt Disney World Resort
    case magicKingdom       = "Magic Kingdom"
    case epcot              = "EPCOT"
    case hollywoodStudios   = "Hollywood Studios"
    case animalKingdom      = "Animal Kingdom"

    // Disneyland Resort
    case disneyland         = "Disneyland"
    case californiaAdventure = "Disney California Adventure"

    var id: String { rawValue }

    /// Label shown in the tab bar. Must be short so six tabs fit comfortably.
    var shortName: String {
        switch self {
        case .magicKingdom:        return "MK"
        case .epcot:               return "EPCOT"
        case .hollywoodStudios:    return "DHS"
        case .animalKingdom:       return "AK"
        case .disneyland:          return "Disneyland"
        case .californiaAdventure: return "DCA"
        }
    }

    /// Full, human-readable park name for navigation titles.
    var displayName: String { rawValue }

    /// The resort a park belongs to (for grouping / stats if ever needed).
    var resort: String {
        switch self {
        case .magicKingdom, .epcot, .hollywoodStudios, .animalKingdom:
            return "Walt Disney World"
        case .disneyland, .californiaAdventure:
            return "Disneyland Resort"
        }
    }

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

    /// Backend park ID used in API calls (e.g. "magic-kingdom").
    /// Distinct from rawValue which is the human-readable display name.
    var backendId: String {
        switch self {
        case .magicKingdom:        return "magic-kingdom"
        case .epcot:               return "epcot"
        case .hollywoodStudios:    return "hollywood-studios"
        case .animalKingdom:       return "animal-kingdom"
        case .disneyland:          return "disneyland"
        case .californiaAdventure: return "california-adventure"
        }
    }

    /// Reverse-lookup a Park from a backend park ID string.
    static func fromBackendId(_ id: String) -> Park? {
        allCases.first { $0.backendId == id }
    }

    var systemImageName: String {
        switch self {
        case .magicKingdom:        return "castle.fill"
        case .epcot:               return "globe.americas.fill"
        case .hollywoodStudios:    return "film.fill"
        case .animalKingdom:       return "leaf.fill"
        case .disneyland:          return "sparkles"
        case .californiaAdventure: return "sun.max.fill"
        }
    }

    /// Ordered lands for this park, used as section headers.
    var lands: [String] {
        switch self {
        case .magicKingdom:
            return [
                "Adventureland",
                "Frontierland",
                "Liberty Square",
                "Fantasyland",
                "Tomorrowland"
            ]
        case .epcot:
            return [
                "World Celebration",
                "World Discovery",
                "World Nature",
                "World Showcase"
            ]
        case .hollywoodStudios:
            return [
                "Hollywood Boulevard",
                "Echo Lake",
                "Sunset Boulevard",
                "Toy Story Land",
                "Star Wars: Galaxy's Edge"
            ]
        case .animalKingdom:
            return [
                "Pandora",
                "Africa",
                "Asia",
                "DinoLand U.S.A."
            ]
        case .disneyland:
            return [
                "Main Street",
                "Adventureland",
                "Frontierland",
                "Fantasyland",
                "Tomorrowland",
                "Star Wars: Galaxy's Edge",
                "Mickey's Toontown"
            ]
        case .californiaAdventure:
            return [
                "Buena Vista Street",
                "Hollywood Land",
                "Avengers Campus",
                "Cars Land",
                "Pacific Wharf",
                "Paradise Gardens Park",
                "Grizzly Peak",
                "Pixar Pier"
            ]
        }
    }
}
