// CommunityRatingSection.swift — "Parkio Community" on the dining detail screen.
//
// One of three distinct things a venue can carry, and the labels do the work of
// keeping them apart:
//
//   Parkio Community  — what other Parkio guests collectively rated, out of 5
//   Parkio editorial  — Parkio's own assessment, out of 10, in the banner below
//   Your private notes— the guest's own journal, which never leaves the device
//
// Header is "Parkio Community" rather than "Guest Rating" on purpose: in a park
// app the user IS a guest, so "Guest Rating" reads as "my rating" — precisely
// the private feature sitting further down the same screen.
//
// Renders nothing at all for the 24 venues with no venueKey, and nothing when
// ratings cannot be read. A restaurant with no ratings and a service that is
// down are different facts, and only the first is ever stated.

import SwiftUI

struct CommunityRatingSection: View {

    let venueKey: String
    let venueName: String
    let accentColor: Color

    @State private var model: CommunityRatingViewModel

    init(venueKey: String, venueName: String, accentColor: Color) {
        self.venueKey = venueKey
        self.venueName = venueName
        self.accentColor = accentColor
        _model = State(wrappedValue: CommunityRatingViewModel(
            venueKey: venueKey,
            service: CommunityRatingService()
        ))
    }

    var body: some View {
        Group {
            switch model.load {
            case .unavailable:
                // Fail soft: the venue screen stays completely usable, and
                // nothing claims this restaurant has no ratings.
                EmptyView()

            case .idle, .loading:
                Section("Parkio Community") {
                    HStack(spacing: AppSpacing.sm) {
                        ProgressView().scaleEffect(0.7).tint(AppColor.textTertiary)
                        Text("Loading guest ratings…")
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                    .padding(.vertical, AppSpacing.xs)
                }
                .listRowBackground(AppColor.card)

            case .zero:
                Section("Parkio Community") { zeroState }
                    .listRowBackground(AppColor.card)

            case .rated(let aggregate):
                Section("Parkio Community") { ratedState(aggregate) }
                    .listRowBackground(AppColor.card)
            }
        }
        .task { model.loadIfNeeded() }
        .sheet(
            isPresented: Binding(
                get: { model.form == .editing || model.form == .submitting || model.form == .failure },
                set: { if !$0 { model.closeForm() } }
            )
        ) {
            CommunityRatingSheet(model: model, venueName: venueName, accentColor: accentColor)
        }
    }

    // MARK: - Zero

    private var zeroState: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // Never "0.0" and never empty stars pretending to be a score.
            Text("No guest ratings yet")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Text("Be the first to rate \(venueName).")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)

            rateButton
            sharedCaption
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Rated

    @ViewBuilder
    private func ratedState(_ aggregate: CommunityRatingAggregate) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.sm) {
                Text(averageText(aggregate.overallAverage))
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Image(systemName: "star.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.brandGold)
                    .accessibilityHidden(true)
                Text(countText(aggregate.ratingCount))
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(
                "Parkio Community rating, \(averageText(aggregate.overallAverage)) out of 5, "
                + "from \(countText(aggregate.ratingCount))"
            )

            // Only dimensions somebody answered, each with its own denominator.
            ForEach(model.visibleDimensions, id: \.name) { row in
                HStack {
                    Text(row.name)
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                    Spacer()
                    Text(averageText(row.average))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("(\(countText(row.count)))")
                        .font(.caption2)
                        .foregroundStyle(AppColor.textTertiary)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(
                    "\(row.name), \(averageText(row.average)) out of 5, from \(countText(row.count))"
                )
            }

            if let mine = model.myRating {
                Divider()
                Text("Your community rating")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                Text(personalSummary(mine))
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)
            }

            if case .success(let outcome) = model.form {
                Text(outcome == .created
                     ? "Thanks — your rating helps other Parkio guests."
                     : "Your rating has been updated.")
                    .font(.caption)
                    .foregroundStyle(accentColor)
            }

            rateButton
            sharedCaption
        }
        .padding(.vertical, AppSpacing.xs)
    }

    // MARK: - Shared pieces

    private var rateButton: some View {
        Button {
            AppHaptic.light()
            model.openForm()
        } label: {
            Text(model.hasPersonalRating ? "Update rating" : "Rate for other guests")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(accentColor)
        }
        .buttonStyle(.plain)
    }

    private var sharedCaption: some View {
        Text("Shared with everyone using Parkio.")
            .font(.caption2)
            .foregroundStyle(AppColor.textTertiary)
    }

    // MARK: - Formatting

    private func averageText(_ average: Double?) -> String {
        guard let average else { return "—" }
        return String(format: "%.1f", average)
    }

    /// "1 rating" / "2 ratings" — never "1 ratings".
    private func countText(_ count: Int) -> String {
        "\(count) \(count == 1 ? "rating" : "ratings")"
    }

    private func personalSummary(_ rating: PersonalDiningRating) -> String {
        var parts = ["Overall \(rating.overall)/5"]
        if let taste = rating.taste { parts.append("Taste \(taste)") }
        if let value = rating.value { parts.append("Value \(value)") }
        if let quality = rating.quality { parts.append("Quality \(quality)") }
        return parts.joined(separator: " · ")
    }
}
