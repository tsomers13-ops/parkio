// DiningRatingSection.swift — "My Rating" List section for the dining detail screen.
//
// Embedded in RideDetailView when attractionType.isDining.
// Ride flows are completely unaffected — this section is never shown for rides,
// shows, character meets, or any non-dining AttractionType.
//
// States:
//   Rated   — star display, favourite badge, notes, last visited date, "Edit Rating" button.
//   Unrated — "You haven't rated this location yet." + "Rate This Location" button.

import SwiftUI

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
