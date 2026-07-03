//
//  Park.swift
//  DisneyRideTracker
//

import SwiftUI

enum Park: String, CaseIterable, Identifiable {
    // Walt Disney World Resort
    case magicKingdom        = "Magic Kingdom"
    case epcot               = "EPCOT"
    case hollywoodStudios     = "Hollywood Studios"
    case animalKingdom        = "Animal Kingdom"

    // Disneyland Resort
    case disneyland           = "Disneyland"
    case californiaAdventure  = "Disney California Adventure"

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

    // MARK: - ThemeParks.wiki entity UUID

    /// ThemeParks.wiki v1 entity UUID for this park.
    ///
    /// Used by `ParkHoursAPIService` (schedule endpoint) and available as a
    /// single source of truth so the UUID isn't duplicated across services.
    /// `WaitTimeService` maintains its own internal copy of these UUIDs for
    /// backward compatibility with its existing resolution logic.
    ///
    /// Source: https://api.themeparks.wiki/v1/destinations (Walt Disney World
    /// and Disneyland Resort destinations, verified 2024-2025).
    var themeparksEntityId: String {
        switch self {
        case .magicKingdom:        return "75ea578a-adc8-4116-a54d-dccb60765ef0"
        case .epcot:               return "47f90d2c-e191-4239-a466-5892ef59a88b"
        case .hollywoodStudios:    return "288747d1-8b4f-4a64-867e-ea7c9b27bad8"
        case .animalKingdom:       return "1c84a229-8862-4648-9c71-378ddd2a7a5c"
        case .disneyland:          return "7340550b-c14d-4def-80bb-acdb51d49a66"
        case .californiaAdventure: return "832fcd51-ea19-4e77-85c7-75d5843b127c"
        }
    }

    // MARK: - Canonical timezone

    /// Park's canonical IANA timezone.
    ///
    /// Used wherever park-local "today" must be computed — e.g. matching a
    /// schedule API response date string to the current calendar day.
    ///
    /// Walt Disney World parks → America/New_York  (Eastern Time)
    /// Disneyland Resort parks → America/Los_Angeles (Pacific Time)
    ///
    /// Force-unwrap is safe: these identifiers are IANA standards that have
    /// been stable since iOS 1 and are guaranteed to resolve.
    var timeZone: TimeZone {
        switch self {
        case .magicKingdom, .epcot, .hollywoodStudios, .animalKingdom:
            // swiftlint:disable:next force_unwrapping
            return TimeZone(identifier: "America/New_York")!
        case .disneyland, .californiaAdventure:
            // swiftlint:disable:next force_unwrapping
            return TimeZone(identifier: "America/Los_Angeles")!
        }
    }

    // MARK: - Design system

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

    // MARK: - Backend / API identifiers

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

    // MARK: - UI metadata

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
    /// Land names MUST match the land strings in RideSeeder.allSeeds exactly.
    var lands: [String] {
        switch self {
        case .magicKingdom:
            return [
                "Main Street, U.S.A.",
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
                "Grand Avenue",
                "Sunset Boulevard",
                "Toy Story Land",
                "Star Wars: Galaxy's Edge"
            ]
        case .animalKingdom:
            return [
                "Discovery Island",
                "Africa",
                "Asia",
                "Pandora"
            ]
        case .disneyland:
            return [
                "Main Street, U.S.A.",
                "Adventureland",
                "New Orleans Square",
                "Critter Country",
                "Frontierland",
                "Fantasyland",
                "Mickey's Toontown",
                "Tomorrowland",
                "Star Wars: Galaxy's Edge"
            ]
        case .californiaAdventure:
            return [
                "Buena Vista Street",
                "Hollywood Land",
                "Avengers Campus",
                "Cars Land",
                "Pixar Pier",
                "Paradise Gardens Park",
                "Grizzly Peak"
            ]
        }
    }
}
