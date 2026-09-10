// CommunityDiscoverySummary.swift — how a Community rating reads on a discovery row.
//
// Pure formatting, deliberately separate from the SwiftUI badge so every rule
// below is testable without rendering anything. It lives beside the service
// rather than in Views for exactly that reason.
//
// The iOS discovery treatment is intentionally NOT the website's "★ 4.6".
// The Dining list already shows the guest's PRIVATE journal rating as a
// five-star strip ("★★★★★ Loved it"), and a second star glyph on the same
// compact row would put two visually similar rating systems side by side. So
// discovery spells the word out instead:
//
//     private    ★★★★★ Loved it          (five glyphs, no count, device-only)
//     community  Community 4.6 · 328 ratings   (named, averaged, counted)
//
// The star is dropped from the visual only. VoiceOver still hears the scale,
// because "Community 4.6" alone does not say out of what.

import Foundation

enum CommunityDiscoverySummary {

    /// Visible row text, or nil when nothing should be shown.
    ///
    /// nil covers all three "show nothing" cases and keeps them
    /// indistinguishable to the caller, which is what the row wants:
    ///   • no summary at all      — ineligible venue, or ratings unavailable
    ///   • ratingCount == 0       — a real zero; the detail page owns the
    ///                              "be the first to rate" invitation
    ///   • count without average  — defensive; never render a bare number
    static func text(for summary: CommunityRatingSummary?, locale: Locale = .current) -> String? {
        guard let summary, summary.ratingCount > 0, let average = summary.overallAverage else {
            return nil
        }
        return "Community \(averageText(average)) · \(countText(summary.ratingCount, locale: locale))"
    }

    /// Screen-reader sentence. States the scale, which the visible text omits.
    static func accessibilityLabel(
        for summary: CommunityRatingSummary?,
        locale: Locale = .current
    ) -> String? {
        guard let summary, summary.ratingCount > 0, let average = summary.overallAverage else {
            return nil
        }
        return "Community rating \(averageText(average)) out of 5 "
            + "from \(countText(summary.ratingCount, locale: locale))"
    }

    // MARK: - Pieces

    /// One decimal, matching the detail screen. Never "4.638", never "5".
    static func averageText(_ average: Double) -> String {
        String(format: "%.1f", average)
    }

    /// "1 rating" / "2 ratings" / "1,204 ratings" — never "1 ratings".
    /// Grouping is locale-aware because a four-figure count is plausible.
    static func countText(_ count: Int, locale: Locale = .current) -> String {
        let formatted = count.formatted(.number.grouping(.automatic).locale(locale))
        return "\(formatted) \(count == 1 ? "rating" : "ratings")"
    }
}
