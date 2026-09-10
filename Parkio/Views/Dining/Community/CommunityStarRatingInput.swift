// CommunityStarRatingInput.swift — 1–5 star input for a Community Rating dimension.
//
// Deliberately NOT the existing StarRatingView. That control represents itself
// to VoiceOver as a single unlabelled Slider ("3 out of 5 stars"), which is
// fine when a screen has exactly one of them — and useless here, where four
// would announce identically with nothing to say which is Taste and which is
// Value. Every row below carries its dimension in its own accessible name.
//
// Whole stars only, matching the backend's validation and the D1 CHECK. No
// half stars, no slider, no typing.

import SwiftUI

struct CommunityStarRatingInput: View {

    /// "Overall", "Taste", … — used in the visible label and, more importantly,
    /// in every star's accessibility label.
    let dimension: String

    /// nil means "not answered", which is a real state: optional dimensions are
    /// omitted from the submission rather than sent as zero.
    @Binding var value: Int?

    /// Optional dimensions say so, so nobody invents an opinion to proceed.
    var isOptional: Bool = false

    var accentColor: Color

    private let stars = 1...5

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {

            HStack(spacing: AppSpacing.sm) {
                Text(dimension)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)

                if isOptional {
                    Text("Optional")
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                }

                Spacer(minLength: AppSpacing.sm)

                // The value as text, so it is never carried by colour alone.
                Text(value.map { "\($0)/5" } ?? "Not rated")
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .accessibilityHidden(true)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach(stars, id: \.self) { star in
                    Button {
                        AppHaptic.selection()
                        withAnimation(AppMotion.quick) {
                            // Tapping the current value clears it, which is the
                            // only way to un-answer an optional dimension.
                            value = (value == star && isOptional) ? nil : star
                        }
                    } label: {
                        Image(systemName: (value ?? 0) >= star ? "star.fill" : "star")
                            .font(.title2)
                            .foregroundStyle(
                                (value ?? 0) >= star ? accentColor : AppColor.textTertiary
                            )
                            .frame(minWidth: 44, minHeight: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(dimension) rating, \(star) out of 5")
                    .accessibilityAddTraits(value == star ? [.isSelected] : [])
                }
            }
            // One clear summary for the group, so a VoiceOver user can hear the
            // current answer without stepping through five buttons.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(
                value.map { "\(dimension) rating, \($0) out of 5" }
                    ?? "\(dimension) rating, not selected"
            )
        }
    }
}
