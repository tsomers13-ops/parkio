// WeatherService.swift — Lightweight park weather via Open-Meteo (no API key required).
//
// Fetches current temperature, WMO condition code, and precipitation probability
// for the active park. Polls every 15 minutes while HomeView is foregrounded.
// Provides a rules-based WeatherSignal so the UI can surface one targeted hint —
// or nothing at all — rather than generic filler text.
//
// Architecture:
//   @Observable @MainActor — created once as @State in HomeView.
//   URLSession.data suspends the actor cleanly; no main-thread blocking.
//   Silent network failures leave the previous snapshot in place or show nothing.

import SwiftUI

// MARK: - Weather Condition

enum WeatherCondition: Equatable {
    case clear
    case partlyCloudy
    case cloudy
    case foggy
    case drizzle
    case rain
    case storm
    case snow
    case unknown

    init(wmoCode: Int) {
        switch wmoCode {
        case 0:              self = .clear
        case 1, 2:           self = .partlyCloudy
        case 3:              self = .cloudy
        case 45, 48:         self = .foggy
        case 51, 53, 55:     self = .drizzle
        case 61, 63, 65,
             80, 81, 82:     self = .rain
        case 71, 73, 75, 77: self = .snow
        case 95, 96, 99:     self = .storm
        default:             self = .unknown
        }
    }

    var label: String {
        switch self {
        case .clear:        return "Sunny"
        case .partlyCloudy: return "Partly Cloudy"
        case .cloudy:       return "Cloudy"
        case .foggy:        return "Foggy"
        case .drizzle:      return "Drizzle"
        case .rain:         return "Rainy"
        case .storm:        return "Stormy"
        case .snow:         return "Snow"
        case .unknown:      return "—"
        }
    }

    var systemImage: String {
        switch self {
        case .clear:        return "sun.max.fill"
        case .partlyCloudy: return "cloud.sun.fill"
        case .cloudy:       return "cloud.fill"
        case .foggy:        return "cloud.fog.fill"
        case .drizzle:      return "cloud.drizzle.fill"
        case .rain:         return "cloud.rain.fill"
        case .storm:        return "cloud.bolt.rain.fill"
        case .snow:         return "snowflake"
        case .unknown:      return "thermometer"
        }
    }
}

// MARK: - Weather Signal (rules engine output)

/// Distilled park-planning advice derived from raw weather numbers.
/// Only non-.none values produce a visible hint.
enum WeatherSignal: Equatable {
    case none       // No strong signal — suppress hint entirely
    case rainSoon   // High precip probability — head outdoors before it hits
    case raining    // Currently raining — prefer covered attractions now
    case hotDay     // Very high temp — indoor rides are a relief

    var hintText: String? {
        switch self {
        case .none:     return nil
        case .rainSoon: return "Rain likely soon — ride outdoor attractions first"
        case .raining:  return "Wet outside — great moment for a covered attraction"
        case .hotDay:   return "Hot outside — perfect time for an indoor ride"
        }
    }

    var hintIcon: String? {
        switch self {
        case .none:     return nil
        case .rainSoon: return "cloud.rain.fill"
        case .raining:  return "umbrella.fill"
        case .hotDay:   return "thermometer.sun.fill"
        }
    }

    var hintColor: Color {
        switch self {
        case .none:            return .clear
        case .rainSoon,
             .raining:         return Color.blue
        case .hotDay:          return AppColor.warning
        }
    }
}

// MARK: - Park Weather (display model)

struct ParkWeather: Equatable {
    let tempF: Int
    let condition: WeatherCondition
    let precipChance: Int   // 0–100

    // MARK: Rules engine

    var signal: WeatherSignal {
        if condition == .rain || condition == .storm { return .raining }
        if precipChance >= 60                        { return .rainSoon }
        if tempF >= 92                               { return .hotDay }
        return .none
    }

    // MARK: Display

    /// Short header string: "84° • Sunny" or "78° • Rain soon"
    var headerDisplay: String {
        if signal == .rainSoon { return "\(tempF)° • Rain soon" }
        return "\(tempF)° • \(condition.label)"
    }

    var weatherHint: String? { signal.hintText }
    var hintIcon: String?    { signal.hintIcon }
    var hintColor: Color     { signal.hintColor }
}

// MARK: - Raw snapshot

struct WeatherSnapshot: Sendable, Equatable {
    let temperatureFahrenheit: Int
    let conditionCode: Int
    let precipitationProbability: Int
    let fetchedAt: Date
}

// MARK: - WeatherService

@Observable
@MainActor
final class WeatherService {

    // MARK: State

    var snapshot: WeatherSnapshot? = nil
    var isLoading = false

    // MARK: Derived

    var current: ParkWeather? {
        guard let s = snapshot else { return nil }
        return ParkWeather(
            tempF: s.temperatureFahrenheit,
            condition: WeatherCondition(wmoCode: s.conditionCode),
            precipChance: s.precipitationProbability
        )
    }

    // MARK: Private

    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 15 * 60   // 15 minutes

    /// Geographic center of each park for weather lookup.
    private static let coords: [Park: (lat: Double, lon: Double)] = [
        .magicKingdom:        (28.4196, -81.5812),
        .epcot:               (28.3747, -81.5494),
        .hollywoodStudios:    (28.3575, -81.5605),
        .animalKingdom:       (28.3579, -81.5900),
        .disneyland:          (33.8127, -117.9190),
        .californiaAdventure: (33.8065, -117.9200),
    ]

    // MARK: - Lifecycle

    func startPolling(for park: Park) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                await self.fetch(for: park)
                try? await Task.sleep(for: .seconds(self.pollInterval))
            }
        }
    }

    func stopPolling() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    /// Call when the user switches parks. Clears stale data immediately.
    func changePark(_ park: Park) {
        snapshot = nil
        startPolling(for: park)
    }

    // MARK: - Fetch

    func fetch(for park: Park) async {
        guard let coords = Self.coords[park] else { return }
        isLoading = (snapshot == nil)

        let urlString =
            "https://api.open-meteo.com/v1/forecast" +
            "?latitude=\(coords.lat)&longitude=\(coords.lon)" +
            "&current=temperature_2m,precipitation_probability,weathercode" +
            "&temperature_unit=fahrenheit&forecast_days=1&timezone=auto"

        guard let url = URL(string: urlString) else {
            isLoading = false
            return
        }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            let response  = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)
            let c = response.current
            snapshot = WeatherSnapshot(
                temperatureFahrenheit: Int(c.temperature_2m.rounded()),
                conditionCode: c.weathercode,
                precipitationProbability: c.precipitation_probability ?? 0,
                fetchedAt: Date()
            )
        } catch {
            // Weather is supplemental — silently preserve existing snapshot on failure.
        }

        isLoading = false
    }
}

// MARK: - Open-Meteo JSON

private struct OpenMeteoResponse: Decodable {
    let current: CurrentWeather

    struct CurrentWeather: Decodable {
        let temperature_2m: Double
        let precipitation_probability: Int?
        let weathercode: Int
    }
}
