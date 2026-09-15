// CommunityRatingForm.swift — the Community rating form.
//
// Explicitly NOT DiningRatingSheet. That sheet edits the private journal —
// favourite, notes, a personal star that never leaves the device. This one
// publishes to every Parkio guest, so it says so, and shares no component with
// it beyond the design tokens.
//
// PUSHED, NOT PRESENTED. This used to be a `.sheet` opened from the dining
// detail — which is itself a sheet. That nested presentation was torn down by
// SwiftUI the moment it appeared, taking the dining detail with it; a 90-line
// reproduction containing no Parkio code showed the hierarchy alone is enough
// to cause it. So the form is now a destination on the NavigationStack
// RideDetailView already owns. It carries no navigation container of its own:
// the stack supplies the title, the back button and the pop.
//
// Numeric only: no written review, no photo, no title. Overall is required;
// Taste, Value and Quality are optional and are omitted from the payload when
// unanswered — never zero, never a copy of Overall.

import SwiftUI

struct CommunityRatingForm: View {

    @Bindable var model: CommunityRatingViewModel
    let venueName: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss

    private var isUpdate: Bool { model.hasPersonalRating }

    var body: some View {
        Form {
                Section {
                    CommunityStarRatingInput(
                        dimension: "Overall",
                        value: $model.draftOverall,
                        accentColor: accentColor
                    )
                } footer: {
                    Text("Your rating helps other Parkio guests decide where to eat.")
                }

                Section {
                    CommunityStarRatingInput(
                        dimension: "Taste",
                        value: $model.draftTaste,
                        isOptional: true,
                        accentColor: accentColor
                    )
                    CommunityStarRatingInput(
                        dimension: "Value",
                        value: $model.draftValue,
                        isOptional: true,
                        accentColor: accentColor
                    )
                    CommunityStarRatingInput(
                        dimension: "Quality",
                        value: $model.draftQuality,
                        isOptional: true,
                        accentColor: accentColor
                    )
                }

                if model.form == .failure {
                    Section {
                        Label(
                            model.formErrorMessage
                                ?? "We couldn't save your rating. Try again.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppColor.error)
                        // A rate-limit sentence is longer than the generic one,
                        // so it must be allowed to wrap at large Dynamic Type
                        // sizes rather than truncate.
                        .fixedSize(horizontal: false, vertical: true)
                    }
                }
        }
        .navigationTitle(isUpdate ? "Update your rating" : "Rate for other guests")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                if model.form == .submitting {
                    ProgressView()
                } else {
                    Button(isUpdate ? "Update" : "Submit") {
                        Task {
                            await model.submit()
                            // Only leave on success — a failure keeps every
                            // selection visible so retry is one tap.
                            if case .success = model.form { dismiss() }
                        }
                    }
                    .disabled(!model.canSubmit)
                }
            }
        }
        // Back is the stack's own button, so there is no Cancel item to own the
        // teardown. Whichever way the guest leaves — back, swipe, or a
        // successful submit — the draft closes exactly once, here.
        .onDisappear { model.closeForm() }
    }
}
