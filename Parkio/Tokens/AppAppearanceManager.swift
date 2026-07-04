// AppAppearanceManager.swift — Manages the user's appearance preference.
//
// Responsibilities
// ────────────────
// • Store the current AppearanceMode preference.
// • Persist it to UserDefaults so the choice survives app restarts.
// • Vend a ColorScheme? for use with .preferredColorScheme() at the app root.
// • Provide AppearanceMode metadata (label, icon) for the settings picker.
//
// Integration
// ───────────
// Injected once via .environment(appearanceManager) in ParkioApp.
// ProfileView reads it to render the picker.
// ParkioApp applies .preferredColorScheme(appearanceManager.colorScheme).
//
// Persistence key
// ───────────────
// "com.disneytracker.appearanceMode" — follows the existing UserDefaultsKey
// namespace used for lastActiveParkId and related keys.

import SwiftUI

// MARK: - AppearanceMode

/// The three options the user can choose in Settings → Appearance.
enum AppearanceMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light  = "light"
    case dark   = "dark"

    var id: String { rawValue }

    /// Display label shown in the settings picker.
    var label: String {
        switch self {
        case .system: return "Follow System"
        case .light:  return "Light"
        case .dark:   return "Dark"
        }
    }

    /// SF Symbol for the picker row icon.
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light:  return "sun.max"
        case .dark:   return "moon"
        }
    }

    /// Maps to a SwiftUI ColorScheme? value for .preferredColorScheme().
    /// nil means "let the system decide" — SwiftUI's default behaviour.
    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light:  return .light
        case .dark:   return .dark
        }
    }
}

// MARK: - AppAppearanceManager

/// Observable manager that persists and vends the app's appearance preference.
///
/// The manager is created once in ParkioApp and injected via
/// .environment(appearanceManager). Any view that needs to read or change
/// the preference accesses it through @Environment(AppAppearanceManager.self).
@Observable
@MainActor
final class AppAppearanceManager {

    private static let defaultsKey = "com.disneytracker.appearanceMode"

    /// Current appearance preference. Assigning a new value persists it
    /// immediately and triggers a re-render at the app root, so the whole
    /// app switches mode without a restart.
    var mode: AppearanceMode {
        didSet { persist() }
    }

    /// ColorScheme? to pass to .preferredColorScheme().
    /// Computed from mode — no separate storage needed.
    var colorScheme: ColorScheme? { mode.colorScheme }

    init() {
        if let raw   = UserDefaults.standard.string(forKey: Self.defaultsKey),
           let saved = AppearanceMode(rawValue: raw) {
            mode = saved
        } else {
            mode = .system     // default: follow the device setting
        }
    }

    // MARK: - Private

    private func persist() {
        UserDefaults.standard.set(mode.rawValue, forKey: Self.defaultsKey)
    }
}
