// StarRatingView.swift — Reusable 1–5 star rating control.
//
// Usage:
//   Interactive:    StarRatingView(rating: $rating)
//   Display-only:  StarRatingView(rating: .constant(3), interactive: false)
//
// Accessibility: presents as a Slider to VoiceOver so ratings are still
// adjustable without tapping individual stars.

import SwiftUI

// MARK: - StarRatingView

struct StarRatingView: View {
    @Binding var rating: Int

    /// SF Symbol size for each star.
    var starFont: Font = .title2

    /// Fill colour for selected stars. Defaults to system yellow.
    var activeColor: Color = Color.yellow

    /// When false, tap gestures are ignored (display-only mode).
    var interactive: Bool = true

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            ForEach(1...5, id: \.self) { star in
                Image(systemName: star <= rating ? "star.fill" : "star")
                    .font(starFont)
                    .foregroundStyle(star <= rating ? activeColor : AppColor.textTertiary)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard interactive else { return }
                        AppHaptic.selection()
                        withAnimation(AppMotion.quick) { rating = star }
                    }
            }
        }
        // Accessibility: expose as a slider so VoiceOver users can swipe to adjust.
        .accessibilityRepresentation {
            Slider(
                value: Binding(
                    get: { Double(rating) },
                    set: { rating = max(1, min(5, Int($0.rounded()))) }
                ),
                in: 1...5,
                step: 1
            )
            .accessibilityLabel("\(rating) out of 5 stars")
        }
    }
}
