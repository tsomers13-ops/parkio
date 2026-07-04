// ParkHoursAPIService.swift — Fetches today's park hours from the ThemeParks.wiki schedule API.
//
// Architecture:
//   ParkHoursAPIService — Swift actor; all network I/O is isolated here.
//   Called by ParkHoursService which drives the 30-minute re-fetch loop and falls
//   back to static hours whenever this service throws.
//
// API endpoint:
//   GET https://api.themeparks.wiki/v1/entity/{uuid}/schedule
//   Returns a JSON object with a `schedule` array. Relevant entry shape:
//     { "date": "2025-01-31",            ← "yyyy-MM-dd" in the park's local timezone
//       "type": "OPERATING",             ← the one we want; skip EXTRA_MAGIC_HOURS etc.
//       "openingTime": "2025-01-31T09:00:00-05:00",   ← ISO 8601 with UTC offset
//       "closingTime":  "2025-01-31T23:00:00-05:00" }
//
// Strategy:
//   1. Build "today" as a "yyyy-MM-dd" string anchored in the park's IANA timezone.
//   2. Filter schedule for entries where date == today && type == "OPERATING".
//   3. Parse openingTime / closingTime via ISO8601DateFormatter — the embedded UTC
//      offset is used directly; no manual timezone arithmetic is performed.
//   4. Return ParkHours(isFallback: false) on success.
//   5. Throw ParkHoursAPIError on any failure — ParkHoursService handles the fallback.
//
// Rate limits (ThemeParks.wiki guidance, April 2025):
//   300 req/min per client; data refreshes every few minutes.
//   ParkHoursService caps fetches to once per 30 minutes per park, well inside limits.
//
// URLSession config mirrors WaitTimeService: 12 s request / 25 s resource timeout.

import Foundation

// MARK: - Error

enum ParkHoursAPIError: Error, CustomStringConvertible {
    case networkError(Error)
    case httpError(Int)
    case decodingError(Error)
    /// No `OPERATING` entry with today's date was found in the response.
    case noScheduleEntry
    /// An entry was found but its openingTime / closingTime could not be parsed.
    case dateParseFailure(String)

    var description: String {
        switch self {
        case .networkError(let e):      return "network: \(e.localizedDescription)"
        case .httpError(let code):      return "HTTP \(code)"
        case .decodingError(let e):     return "decode: \(e.localizedDescription)"
        case .noScheduleEntry:          return "no OPERATING entry for today"
        case .dateParseFailure(let s):  return "date parse failure: \(s)"
        }
    }
}

// MARK: - Private DTOs

private struct TPWScheduleResponse: Decodable {
    let id:         String
    let name:       String?
    let entityType: String?
    let timezone:   String?
    let schedule:   [TPWScheduleEntry]
}

private struct TPWScheduleEntry: Decodable {
    /// "yyyy-MM-dd" in the park's local timezone — no time component.
    let date:        String
    /// e.g. "OPERATING", "EXTRA_MAGIC_HOURS", "TICKETED_EVENT", "INFO"
    let type:        String
    /// ISO 8601 with embedded UTC offset. Absent on closed / info-only entries.
    let openingTime: String?
    let closingTime: String?
}

// MARK: - Service

/// Lightweight actor that fetches today's operating hours from ThemeParks.wiki.
///
/// Use the `shared` singleton. The actor serialises all access so concurrent
/// callers cannot produce overlapping in-flight requests from the same instance.
actor ParkHoursAPIService {

    // MARK: Singleton

    static let shared = ParkHoursAPIService()
    private init() {}

    // MARK: Private state

    private let session: URLSession = {
        let cfg = URLSessionConfiguration.default
        cfg.timeoutIntervalForRequest  = 12   // matches WaitTimeService
        cfg.timeoutIntervalForResource = 25
        return URLSession(configuration: cfg)
    }()

    private let baseURL = URL(string: "https://api.themeparks.wiki/v1")!

    // ThemeParks.wiki occasionally includes fractional seconds; keep both formatters
    // so a missing fractional-seconds field does not silently swallow a valid timestamp.
    private let isoWithFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private let isoNoFraction: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    // MARK: - Public

    /// Fetch today's OPERATING hours for `park` from ThemeParks.wiki.
    ///
    /// The ISO 8601 timestamps in the response carry an embedded UTC offset (e.g.
    /// `-05:00` for Eastern). `ISO8601DateFormatter` uses that offset directly and
    /// returns a timezone-agnostic `Date` (UTC epoch). No manual offset arithmetic
    /// is performed. The caller's `ParkHours.formattedTime` then re-formats the
    /// `Date` using `park.timeZone` for display, guaranteeing EPCOT "Closes at
    /// 9:00 PM" can never display as 10:00 PM regardless of device locale.
    ///
    /// - Returns: A `ParkHours` value with `isFallback: false`.
    /// - Throws:  `ParkHoursAPIError` on any failure. Caller falls back to static hours.
    func fetchTodayHours(for park: Park) async throws -> ParkHours {

        let tz          = park.timeZone
        let todayString = Self.todayDateString(in: tz)

        #if DEBUG
        print("[ParkHoursAPIService] → fetch  park: \(park.displayName)")
        print("[ParkHoursAPIService]   entity: \(park.themeparksEntityId)")
        print("[ParkHoursAPIService]   tz:     \(tz.identifier)")
        print("[ParkHoursAPIService]   today:  \(todayString)")
        #endif

        // ── Build request ───────────────────────────────────────────────────────
        let url = baseURL
            .appendingPathComponent("entity")
            .appendingPathComponent(park.themeparksEntityId)
            .appendingPathComponent("schedule")

        var request = URLRequest(url: url)
        request.setValue(
            "Parkio/1.0 (iOS; ParkHoursAPIService)",
            forHTTPHeaderField: "User-Agent"
        )

        // ── Network fetch ───────────────────────────────────────────────────────
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            #if DEBUG
            print("[ParkHoursAPIService] ✗ network error: \(error)")
            #endif
            throw ParkHoursAPIError.networkError(error)
        }

        if let http = response as? HTTPURLResponse,
           !(200..<300).contains(http.statusCode) {
            #if DEBUG
            print("[ParkHoursAPIService] ✗ HTTP \(http.statusCode)")
            #endif
            throw ParkHoursAPIError.httpError(http.statusCode)
        }

        // ── Decode ──────────────────────────────────────────────────────────────
        let decoded: TPWScheduleResponse
        do {
            decoded = try JSONDecoder().decode(TPWScheduleResponse.self, from: data)
        } catch {
            #if DEBUG
            print("[ParkHoursAPIService] ✗ decode error: \(error)")
            #endif
            throw ParkHoursAPIError.decodingError(error)
        }

        // ── Find today's OPERATING entry ─────────────────────────────────────────
        guard let entry = decoded.schedule.first(where: {
            $0.date == todayString && $0.type == "OPERATING"
        }) else {
            #if DEBUG
            let available = decoded.schedule.map { "\($0.date)/\($0.type)" }.joined(separator: ", ")
            print("[ParkHoursAPIService] ✗ no OPERATING entry for \(todayString). Available: \(available.isEmpty ? "(empty)" : available)")
            #endif
            throw ParkHoursAPIError.noScheduleEntry
        }

        #if DEBUG
        print("[ParkHoursAPIService]   matched date: \(entry.date)  open: \(entry.openingTime ?? "nil")  close: \(entry.closingTime ?? "nil")")
        #endif

        guard let openStr  = entry.openingTime,
              let closeStr = entry.closingTime else {
            throw ParkHoursAPIError.noScheduleEntry
        }

        // ── Parse timestamps ─────────────────────────────────────────────────────
        // ISO8601DateFormatter interprets the embedded UTC offset and returns a Date
        // (UTC epoch). No timezone math is needed here; display formatting is handled
        // in ParkHours.formattedTime using park.timeZone.
        guard let openTime  = parseISO(openStr),
              let closeTime = parseISO(closeStr) else {
            #if DEBUG
            print("[ParkHoursAPIService] ✗ date parse failure: \"\(openStr)\" / \"\(closeStr)\"")
            #endif
            throw ParkHoursAPIError.dateParseFailure("\(openStr) / \(closeStr)")
        }

        #if DEBUG
        let displayFmt = DateFormatter()
        displayFmt.timeStyle = .short
        displayFmt.timeZone  = tz
        print("[ParkHoursAPIService] ✓ parsed  open: \(displayFmt.string(from: openTime))  close: \(displayFmt.string(from: closeTime)) [\(tz.identifier)]")
        #endif

        return ParkHours(
            openTime:     openTime,
            closeTime:    closeTime,
            parkTimeZone: tz,
            isFallback:   false
        )
    }

    // MARK: - Private helpers

    /// "yyyy-MM-dd" for today in `tz` — matches the `date` field in the API response.
    private static func todayDateString(in tz: TimeZone) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd"
        fmt.timeZone   = tz
        return fmt.string(from: Date())
    }

    /// Tries the fractional-seconds formatter first; falls back to the plain variant.
    private func parseISO(_ string: String) -> Date? {
        isoWithFraction.date(from: string) ?? isoNoFraction.date(from: string)
    }
}
