// ParkHoursService.swift — Park-hours model, 60-second refresh loop, and API integration.
//
// Architecture:
//   ParkHours        — value type; all derived state (isOpen, countdown, status text).
//   ParkHoursService — @Observable @MainActor; two async loops:
//                        • 60-second clock tick  → keeps countdown strings fresh (no network)
//                        • 30-minute API re-fetch → upgrades hours from ThemeParks.wiki
//
// Data sources (priority order):
//   1. ThemeParks.wiki schedule API (via ParkHoursAPIService) — live, today-specific.
//      Cached in `apiHours`; used whenever the cached value is for today in the park's tz.
//   2. Static fallback schedule (makeStaticHours) — never fails; based on typical
//      published Disney hours split by day-of-week tier (Mon–Thu vs Fri–Sun).
//
// Timezone handling:
//   Walt Disney World parks → America/New_York  (Eastern Time)
//   Disneyland Resort parks → America/Los_Angeles (Pacific Time)
//   Timezone is sourced from `Park.timeZone` — single authoritative property on the
//   model — rather than a private dictionary. No manual UTC-offset arithmetic is done
//   anywhere in this file: ISO 8601 timestamps are parsed by ISO8601DateFormatter
//   (which honours the embedded offset), and display strings are formatted by
//   DateFormatter with timeZone = parkTimeZone. EPCOT 9 PM always displays as 9 PM.
//
// isFallback flag:
//   ParkHours.isFallback == true  → built from static schedule (DEBUG-only)
//   ParkHours.isFallback == false → parsed from the live API; confirmed for today
//
// Rate-limit safety:
//   ThemeParks.wiki guidance: 300 req/min, data refreshes every few minutes.
//   This service fetches at most once per 30 minutes (apiRefetchInterval), well
//   inside limits. Fetches never happen inside a SwiftUI body or on every render.
//   `triggerAPIFetch` cancels any in-flight task before starting a new one;
//   a `Task.isCancelled` guard in `performAPIFetch` prevents a cancelled task's
//   continuation from writing stale data alongside a newer task's result.
//
// Static schedule bug-fixes (unchanged from previous revision):
//
//   1. DayTier.extended now covers Fri + Sat + Sun. Friday was previously
//      treated as a standard weekday, producing wrong close times.
//
//   2. Animal Kingdom close times corrected to 17:30 (standard) / 19:00 (extended).
//      Previous values (18:00 / 20:00) caused closing-soon logic to fire late.
//
//   3. Hollywood Studios open time corrected to 8:00 AM (was 9:00 AM).

import SwiftUI

// MARK: - DayTier

/// Classifies a day into standard (Mon–Thu) or extended (Fri–Sun) hours.
private enum DayTier {
    case standard   // Monday – Thursday
    case extended   // Friday – Sunday

    /// - Parameter weekday: `Calendar.component(.weekday)` result (1 = Sun … 7 = Sat).
    init(weekday: Int) {
        self = (weekday == 1 || weekday >= 6) ? .extended : .standard
    }
}

// MARK: - ParkHours

struct ParkHours: Equatable {
    let openTime:     Date
    let closeTime:    Date
    let parkTimeZone: TimeZone
    /// True when this value was built from the static fallback schedule.
    /// For DEBUG logging only — never shown in production UI.
    let isFallback:   Bool

    /// Designated initialiser. `isFallback` defaults to `false` so all existing
    /// construction sites (previews, tests, static schedule path) compile unchanged.
    init(openTime: Date,
         closeTime: Date,
         parkTimeZone: TimeZone,
         isFallback: Bool = false) {
        self.openTime     = openTime
        self.closeTime    = closeTime
        self.parkTimeZone = parkTimeZone
        self.isFallback   = isFallback
    }

    // MARK: Derived state

    var isOpen: Bool {
        let now = Date()
        return now >= openTime && now < closeTime
    }

    /// Minutes remaining until close. `nil` when the park is not currently open.
    var minutesUntilClose: Int? {
        guard isOpen else { return nil }
        let secs = closeTime.timeIntervalSince(Date())
        return secs > 0 ? Int(secs / 60) : nil
    }

    /// Minutes until the park opens today. `nil` when already open or past closing.
    var minutesUntilOpen: Int? {
        let now = Date()
        guard now < openTime else { return nil }
        return Int(openTime.timeIntervalSince(now) / 60)
    }

    /// True when the park closes within the next 2 hours.
    var isClosingSoon: Bool {
        guard let mins = minutesUntilClose else { return false }
        return mins <= 120
    }

    // MARK: Display strings

    /// Compact one-line status string for the Home header.
    ///
    ///   "Open now • Closes at 9:00 PM"    (> 3 h remaining)
    ///   "Open now • Closes in 2h 15m"     (≤ 3 h remaining)
    ///   "Open now • Closes in 45m"         (< 1 h remaining)
    ///   "Closed • Opens at 9:00 AM"        (not yet open today)
    ///   "Closed today"                     (already past closing)
    var statusText: String {
        if isOpen {
            guard let mins = minutesUntilClose else { return "Open now" }
            if mins <= 180 {
                return "Open now • \(countdownText(mins))"
            }
            return "Open now • Closes at \(formattedTime(closeTime))"
        } else {
            if minutesUntilOpen != nil {
                return "Closed • Opens at \(formattedTime(openTime))"
            }
            return "Closed today"
        }
    }

    /// Short hint for the Best Next Ride card when closing soon.
    var closingSoonHint: String {
        guard let mins = minutesUntilClose else { return "Park closing soon" }
        if mins <= 30  { return "Closing very soon — skip long waits" }
        if mins <= 60  { return "Less than 1 hour left — focus on short waits" }
        return "Closing soon — prioritize nearby rides"
    }

    // MARK: Private helpers

    private func countdownText(_ minutes: Int) -> String {
        if minutes < 60 { return "Closes in \(minutes)m" }
        let h = minutes / 60
        let m = minutes % 60
        return m == 0 ? "Closes in \(h)h" : "Closes in \(h)h \(m)m"
    }

    private func formattedTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        f.timeZone  = parkTimeZone
        return f.string(from: date)
    }
}

// MARK: - ParkHoursService

@Observable
@MainActor
final class ParkHoursService {

    // MARK: Published state

    /// The current best-available park hours. `nil` only on very first call before
    /// the static schedule has been computed. UI should show "Hours unavailable" when nil.
    var current: ParkHours? = nil

    // MARK: Private

    private var activePark:  Park?

    /// Clock-tick task — wakes every 60 s and calls `refresh()` to keep countdown
    /// strings current. No network activity happens here.
    private var pollingTask: Task<Void, Never>?
    private let pollInterval: TimeInterval = 60

    /// API re-fetch task — wakes every 30 min and calls `performAPIFetch()`.
    /// Also handles the initial fetch on `start` / `changePark` / `forceRefresh`.
    private var apiFetchTask: Task<Void, Never>?
    private let apiRefetchInterval: TimeInterval = 1800   // 30 minutes

    /// Most recent hours returned by the ThemeParks.wiki API for the current park.
    /// Nil until the first successful fetch; treated as stale after midnight in the
    /// park's timezone (checked by `isTodayInParkTimezone` in `refresh()`).
    private var apiHours: ParkHours? = nil

    // MARK: - Lifecycle

    /// Start both loops for `park`. Safe to call multiple times — cancels previous loops.
    func start(for park: Park) {
        activePark = park
        refresh()

        pollingTask?.cancel()
        pollingTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.pollInterval ?? 60))
                guard !Task.isCancelled else { return }
                self?.refresh()
            }
        }

        triggerAPIFetch(for: park)
    }

    func stop() {
        pollingTask?.cancel()
        pollingTask  = nil
        apiFetchTask?.cancel()
        apiFetchTask = nil
    }

    /// Switch active park — clears stale cached data, surfaces static hours
    /// immediately, then kicks off a fresh API fetch in the background.
    func changePark(_ park: Park) {
        current    = nil
        apiHours   = nil
        activePark = park
        refresh()
        triggerAPIFetch(for: park)
    }

    /// Invalidate the cached API hours and trigger an immediate re-fetch.
    /// Intended for wiring into the pull-to-refresh gesture; returns immediately
    /// (the fetch runs in the background).
    func forceRefresh() {
        guard let park = activePark else { return }
        apiHours = nil
        refresh()               // surface static fallback right away
        triggerAPIFetch(for: park)
    }

    // MARK: - Refresh (clock tick)

    /// Re-derive `current` from the best available source without any network I/O.
    /// Called every 60 s and immediately on park changes so countdown strings stay fresh.
    private func refresh() {
        guard let park = activePark else { return }

        if let live = apiHours, isTodayInParkTimezone(live.openTime, tz: park.timeZone) {
            current = live
            #if DEBUG
            print("[ParkHoursService] refresh — source: API  park: \(park.displayName)  isOpen: \(live.isOpen)  status: \"\(live.statusText)\"")
            #endif
        } else {
            let staticHours = Self.makeStaticHours(for: park, on: Date())
            current = staticHours
            #if DEBUG
            if let s = staticHours {
                print("[ParkHoursService] refresh — source: static  park: \(park.displayName)  isOpen: \(s.isOpen)  status: \"\(s.statusText)\"")
            }
            #endif
        }
    }

    // MARK: - API fetch loop

    /// Cancels any existing API task and starts a new one for `park`.
    /// Performs an immediate fetch, then re-fetches every `apiRefetchInterval` seconds.
    /// Fire-and-forget — callers do not await the result.
    private func triggerAPIFetch(for park: Park) {
        apiFetchTask?.cancel()
        apiFetchTask = Task { @MainActor [weak self] in
            // Immediate fetch on entry
            await self?.performAPIFetch(for: park)

            // Periodic re-fetch
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(self?.apiRefetchInterval ?? 1800))
                guard !Task.isCancelled else { return }
                guard self?.activePark == park else { return }
                await self?.performAPIFetch(for: park)
            }
        }
    }

    /// Calls `ParkHoursAPIService.shared.fetchTodayHours` and promotes the result.
    ///
    /// On success: updates `apiHours` and `current`.
    /// On failure: logs; keeps whatever static fallback `refresh()` already placed in `current`.
    private func performAPIFetch(for park: Park) async {
        let tz          = park.timeZone
        let todayString = Self.localDateString(for: tz)

        #if DEBUG
        print("[ParkHoursService] → API fetch  park: \(park.displayName)  entity: \(park.themeparksEntityId)  tz: \(tz.identifier)  local date: \(todayString)")
        #endif

        do {
            let hours = try await ParkHoursAPIService.shared.fetchTodayHours(for: park)

            // A Task.isCancelled guard is essential here: if `triggerAPIFetch` was
            // called again (e.g. forceRefresh or changePark) while the network request
            // was in flight, the old task is cancelled but its continuation still runs
            // after the await. Without this guard, both the cancelled task and the new
            // task would write to apiHours/current simultaneously.
            guard !Task.isCancelled else {
                #if DEBUG
                print("[ParkHoursService] Discarding result — task was cancelled during fetch (park: \(park.displayName))")
                #endif
                return
            }

            // Also discard if the active park changed while suspended on the network call.
            guard activePark == park else {
                #if DEBUG
                print("[ParkHoursService] Discarding result — park changed during fetch (was: \(park.displayName))")
                #endif
                return
            }

            apiHours = hours
            current  = hours

            #if DEBUG
            let fmt = DateFormatter()
            fmt.timeStyle = .short
            fmt.timeZone  = tz
            let openStr  = fmt.string(from: hours.openTime)
            let closeStr = fmt.string(from: hours.closeTime)
            print("[ParkHoursService] ✓ live hours  park: \(park.displayName)  open: \(openStr)  close: \(closeStr)  tz: \(tz.identifier)  isFallback: \(hours.isFallback)")
            print("[ParkHoursService]   isOpen: \(hours.isOpen)  minutesUntilClose: \(hours.minutesUntilClose.map { "\($0)" } ?? "nil")  label: \"\(hours.statusText)\"")
            #endif

        } catch {
            #if DEBUG
            print("[ParkHoursService] ✗ API failed — park: \(park.displayName)  error: \(error)  fallback: true")
            if let fallback = current {
                print("[ParkHoursService]   fallback label: \"\(fallback.statusText)\"")
            }
            #endif
            // `current` already contains static fallback hours set by the preceding
            // `refresh()` call; no further action is required.
        }
    }

    // MARK: - Static schedule

    /// Builds a `ParkHours` from the hardcoded typical-hours schedule.
    ///
    /// Exposed as `static` so previews and unit tests can construct values directly.
    /// Renamed from `makeHours` to `makeStaticHours` to distinguish from the API path.
    static func makeStaticHours(for park: Park, on date: Date) -> ParkHours? {
        let tz = park.timeZone
        var cal      = Calendar(identifier: .gregorian)
        cal.timeZone = tz

        // Weekday is derived in park-local time so a Friday evening in a different
        // device locale still resolves to the park's Friday schedule tier.
        let weekday = cal.component(.weekday, from: date)   // 1 = Sun … 7 = Sat
        let tier    = DayTier(weekday: weekday)

        let (openH, openM, closeH, closeM) = schedule(for: park, tier: tier)

        guard
            let openTime  = cal.date(bySettingHour: openH,  minute: openM,  second: 0, of: date),
            let closeTime = cal.date(bySettingHour: closeH, minute: closeM, second: 0, of: date)
        else { return nil }

        return ParkHours(
            openTime:     openTime,
            closeTime:    closeTime,
            parkTimeZone: tz,
            isFallback:   true
        )
    }

    // MARK: - Private helpers

    /// Returns true when `date` falls on today's calendar day in `tz`.
    /// Used to decide whether a cached `apiHours` value is still valid after midnight.
    private func isTodayInParkTimezone(_ date: Date, tz: TimeZone) -> Bool {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = tz
        return cal.isDateInToday(date)
    }

    /// "yyyy-MM-dd" for today in `tz` — used for DEBUG logs and API date matching.
    private static func localDateString(for tz: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone   = tz
        return fmt.string(from: Date())
    }

    /// Typical published hours per park, by day tier.
    ///
    /// Standard = Mon–Thu  |  Extended = Fri–Sun
    ///
    /// Sources: Walt Disney World and Disneyland resort calendars, 2024–2025.
    /// These reflect commonly published non-holiday, non-event hours.
    /// Special events (MNSSHP, MVMCP, EPCOT festivals, RunDisney) will differ.
    ///
    /// Returns: (openHour, openMinute, closeHour, closeMinute) in park-local time.
    private static func schedule(for park: Park, tier: DayTier) -> (Int, Int, Int, Int) {
        switch park {

        // ── Walt Disney World ──────────────────────────────────────────────────

        case .magicKingdom:
            // 9 AM open. Weeknight 10 PM; Fri–Sun 11 PM.
            return tier == .extended ? (9, 0, 23, 0) : (9, 0, 22, 0)

        case .epcot:
            // 9 AM open. Weeknight 9 PM; Fri–Sun 10 PM (World Showcase stays later).
            return tier == .extended ? (9, 0, 22, 0) : (9, 0, 21, 0)

        case .hollywoodStudios:
            // DHS routinely opens at 8 AM (not 9 AM — previous bug).
            // Weeknight close 9 PM; Fri–Sun 10 PM.
            return tier == .extended ? (8, 0, 22, 0) : (8, 0, 21, 0)

        case .animalKingdom:
            // AK is Disney's earliest-closing park.
            // Standard: 8 AM – 5:30 PM. Extended: 8 AM – 7:00 PM.
            // Previous values (18:00 / 20:00) were 30 min – 2.5 h too late.
            return tier == .extended ? (8, 0, 19, 0) : (8, 0, 17, 30)

        // ── Disneyland Resort ─────────────────────────────────────────────────

        case .disneyland:
            // Weekdays 9 AM – 10 PM; Fri–Sun 8 AM – 11 PM.
            return tier == .extended ? (8, 0, 23, 0) : (9, 0, 22, 0)

        case .californiaAdventure:
            // Weekdays 9 AM – 9 PM; Fri–Sun 9 AM – 10 PM.
            return tier == .extended ? (9, 0, 22, 0) : (9, 0, 21, 0)
        }
    }
}
