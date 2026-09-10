// CommunityRatingBadge.swift — the compact Community signal on a Dining discovery row.
//
// Text only, by design: no star glyph. The row already renders the guest's
// PRIVATE journal rating as a five-star strip, and a second star here would
// put two visually similar systems into one compact line. Naming the thing —
// "Community" — separates them more reliably than any icon could.
//
// Overall average and count only. Taste, Value and Quality stay on the detail
// page; a discovery row answers "do other people like this?", not "why".
//
// Renders nothing when there is nothing honest to say — see
// CommunityDiscoverySummary for the three cases that collapse to nil.

import SwiftUI

struct CommunityRatingBadge: View {

    /// nil for an ineligible venue, or when ratings could not be read.
    let summary: CommunityRatingSummary?

    var body: some View {
        if let text = CommunityDiscoverySummary.text(for: summary) {
            Text(text)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                // Wraps rather than truncating. At accessibility text sizes a
                // single line clips to "Community 5.0…", dropping the count —
                // and an average with no sample size is precisely the
                // impression this feature must not give.
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                // The visible text omits "out of 5"; the accessible name
                // restores it, so VoiceOver never hears a bare number.
                .accessibilityLabel(
                    CommunityDiscoverySummary.accessibilityLabel(for: summary) ?? text
                )
        }
    }
}
