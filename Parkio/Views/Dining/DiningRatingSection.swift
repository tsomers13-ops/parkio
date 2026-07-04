// DiningRatingSection.swift — "My Rating" List section for the dining detail screen.
//
// Embedded in RideDetailView when attractionType.isDining.
// Ride flows are completely unaffected — this section is never shown for rides,
// shows, character meets, or any non-dining AttractionType.
//
// Phase 2 additions:
//   DiningRecommendationSection — context-aware summary banner rendered as a
//   separate List section ABOVE "My Rating". Shows:
//     • Rated + favourite  → "One of your favorites · Visited [date]"
//     • Rated ★★★★★        → "Loved this last trip · Visited [date]"
//     • Rated ★★★★☆        → "Really enjoyed this · Visited [date]"
//     • Rated ★★★☆☆        → "Decent, worth a try · Visited [date]"
//     • Rated ★★☆☆☆/★☆☆☆☆ → "Avoid? …" or "Previously rated …" + date
//     • Unrated            → "Haven't tried this yet · Parkio: N/10"
//
// DiningRatingSection (existing) — stars, heart, label, notes, date, edit.

import SwiftUI

// MARK: - DiningRecommendationSection

/// Read-only List section that surfaces a one-line contextual summary of the
/// user's relationship with a dining venue. Rendered above DiningRatingSection
/// in RideDetailView so the guest sees context before diving into edit controls.
///
/// Read-only — no interactive elements, no sheet presentation.
struct DiningRecommendationSection: View {
    let ride:        Ride
    let accentColor: Color

    @Environment(DiningRatingStore.self) private var ratingStore

    private var currentRating: DiningRating? { ratingStore.rating(for: ride.id) }

    private var recommendation: DiningRecommendation {
        let master = RideMasterData.all.first { $0.stableID == ride.id }
            ?? MasterAttraction(ride.name, park: Park(rawValue: ride.park) ?? .magicKingdom,
                                land: ride.land, type: .quickService, seed: false)
        return DiningRecommendationService.recommend(venue: master, store: ratingStore)
    }

    var body: some View {
        Section {
            HStack(spacing: AppSpacing.md) {
                // ── Icon ────────────────────────────────────────────
                ZStack {
                    Circle()
                        .fill(iconBackgroundColor)
                        .frame(width: 36, height: 36)
                    Image(systemName: recommendation.label.systemImage)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(iconForegroundColor)
                }

                // ── Primary + secondary lines ────────────────────────
                VStack(alignment: .leading, spacing: 2) {
                    Text(recommendation.label.displayString)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(
                            recommendation.label.isPositive
                                ? AppColor.textPrimary
                                : AppColor.textSecondary
                        )

                    Text(secondaryLine)
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                }

                Spacer()
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .listRowBackground(AppColor.card)
    }

    // MARK: - Helpers

    private var secondaryLine: String {
        if let r = currentRating, let visited = r.lastVisited {
            let formatted = visited.formatted(date: .abbreviated, time: .omitted)
            return "Last visited \(formatted)"
        }
        // Unvisited — show Parkio score as context
        if let score = RideMasterData.diningByStableID[ride.id]?.parkioScore {
            return "Parkio rates this \(score) / 10"
        }
        return "No visit recorded yet"
    }

    private var iconBackgroundColor: Color {
        switch recommendation.label {
        case .markedFavorite:              return AppColor.error.opacity(0.12)
        case .lovedLastTrip, .highlyRated: return accentColor.opacity(0.12)
        case .wouldAvoid:                  return AppColor.brandGoldDeep.opacity(0.12)
        default:                           return AppColor.skeleton.opacity(0.5)
        }
    }

    private var iconForegroundColor: Color {
        switch recommendation.label {
        case .markedFavorite:              return AppColor.error
        case .lovedLastTrip, .highlyRated: return accentColor
        case .wouldAvoid:                  return AppColor.brandGoldDeep
        default:                           return AppColor.textTertiary
        }
    }
}

// MARK: - DiningRatingSection

struct DiningRatingSection: View {
    let ride: Ride
    let accentColor: Color

    @Environment(DiningRatingStore.self) private var ratingStore
    @State private var showSheet = false

    /// Current rating, re-evaluated each time ratingStore.ratings changes.
    private var currentRating: DiningRating? {
        ratingStore.rating(for: ride.id)
    }

    // MARK: - Body

    var body: some View {
        Section("My Rating") {
            content
        }
        .listRowBackground(AppColor.card)
        .sheet(isPresented: $showSheet) {
            DiningRatingSheet(
                ride:        ride,
                existing:    currentRating,
                accentColor: accentColor
            )
        }
    }

    // MARK: - Content router

    @ViewBuilder
    private var content: some View {
        if let existing = currentRating {
            ratedView(existing)
        } else {
            unratedView
        }
    }

    // MARK: - Rating label helper

    private func ratingLabel(for stars: Int) -> String {
        switch stars {
        case 5: return "Loved it"
        case 4: return "Great"
        case 3: return "Good"
        case 2: return "Just OK"
        default: return "Wouldn't Return"
        }
    }

    // MARK: - Rated state

    @ViewBuilder
    private func ratedView(_ rating: DiningRating) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // Stars + favourite icon
            HStack(alignment: .center) {
                StarRatingView(
                    rating:      .constant(rating.rating),
                    starFont:    .title3,
                    activeColor: accentColor,
                    interactive: false
                )

                Spacer()

                if rating.isFavorite {
                    Image(systemName: "heart.fill")
                        .foregroundStyle(AppColor.error)
                        .accessibilityLabel("Marked as favourite")
                }
            }

            // Descriptive label beneath the stars
            Text(ratingLabel(for: rating.rating))
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)

            // Notes
            if !rating.notes.isEmpty {
                Text(rating.notes)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Last visited
            if let lastVisited = rating.lastVisited {
                Label(
                    "Visited \(lastVisited.formatted(date: .abbreviated, time: .omitted))",
                    systemImage: "calendar"
                )
                .font(.caption)
                .foregroundStyle(AppColor.textTertiary)
            }

            // Edit button
            Button {
                AppHaptic.light()
                showSheet = true
            } label: {
                Text("Edit Rating")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(accentColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Unrated state

    private var unratedView: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("You haven't rated this location yet.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            Button("Rate This Location") {
                AppHaptic.light()
                showSheet = true
            }
            .buttonStyle(.borderedProminent)
            .tint(accentColor)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}
