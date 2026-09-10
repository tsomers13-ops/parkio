// ParkioAPI.swift — where the Parkio backend lives, and the exact paths it serves.
//
// This is the app's first Parkio-owned backend client (the existing services
// talk to themeparks.wiki and open-meteo), so the host is defined once, here,
// rather than sprinkled through call sites.
//
// Release is hard-pinned to Production. The override below is compiled out
// entirely outside DEBUG, so a Preview URL cannot ship in a release build even
// if a stale value is left in Info.plist.
//
// Nothing here is secret. The base URL is public; the rating credential is not
// configuration and lives only in the Keychain.

import Foundation

enum ParkioAPI {

    // MARK: - Host

    /// The live Parkio website, which also serves the ratings API.
    static let productionBaseURL = URL(string: "https://parkio.info")!

    /// Info.plist key a DEBUG build may set to point at a Preview deployment,
    /// e.g. "https://preview-something.parkio.pages.dev".
    static let baseURLOverrideKey = "ParkioAPIBaseURL"

    /// The base URL for this build.
    ///
    /// DEBUG honours the Info.plist override so a developer can validate
    /// against Preview without editing source. Release ignores it completely.
    static var baseURL: URL {
        #if DEBUG
        if let raw = Bundle.main.object(forInfoDictionaryKey: baseURLOverrideKey) as? String,
           let url = URL(string: raw),
           url.scheme == "https" {
            return url
        }
        #endif
        return productionBaseURL
    }

    // MARK: - Paths
    //
    // The website runs `trailingSlash: true`. Without the trailing slash Next
    // answers 308 and URLSession replays the redirect as a GET, silently
    // dropping a POST body. These builders exist so no call site can forget.

    static func ratingsPath(venueKey: String) -> String {
        "/api/dining/\(escape(venueKey))/ratings/"
    }

    static func myRatingPath(venueKey: String) -> String {
        "/api/dining/\(escape(venueKey))/ratings/me/"
    }

    static func bulkRatingsPath(venueKeys: [String]) -> String {
        let joined = venueKeys.map(escape).joined(separator: ",")
        return "/api/dining/ratings/?venueKeys=\(joined)"
    }

    static let anonymousIdentityPath = "/api/identity/anonymous/"

    // MARK: - URL building

    static func url(path: String, base: URL? = nil) -> URL? {
        URL(string: path, relativeTo: base ?? baseURL)?.absoluteURL
    }

    private static func escape(_ value: String) -> String {
        value.addingPercentEncoding(withAllowedCharacters: .parkioPathSafe) ?? value
    }
}

private extension CharacterSet {
    /// Unreserved characters only. venueKeys are `[a-z0-9-]`, so this is a
    /// belt-and-braces guard rather than a transformation that normally does
    /// anything.
    static let parkioPathSafe: CharacterSet = {
        var set = CharacterSet.alphanumerics
        set.insert(charactersIn: "-._~")
        return set
    }()
}
