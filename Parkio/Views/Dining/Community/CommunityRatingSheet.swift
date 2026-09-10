// CommunityRatingSheet.swift — the Community rating form.
//
// Explicitly NOT DiningRatingSheet. That sheet edits the private journal —
// favourite, notes, a personal star that never leaves the device. This one
// publishes to every Parkio guest, so it says so, and shares no component with
// it beyond the design tokens.
//
// Numeric only: no written review, no photo, no title. Overall is required;
// Taste, Value and Quality are optional and are omitted from the payload when
// unanswered — never zero, never a copy of Overall.

import SwiftUI

struct CommunityRatingSheet: View {

    @Bindable var model: CommunityRatingViewModel
    let venueName: String
    let accentColor: Color

    @Environment(\.dismiss) private var dismiss

    private var isUpdate: Bool { model.hasPersonalRating }

    var body: some View {
        NavigationStack {
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
                            "We couldn't save your rating. Try again.",
                            systemImage: "exclamationmark.triangle"
                        )
                        .font(.subheadline)
                        .foregroundStyle(AppColor.error)
                    }
                }
            }
            .navigationTitle(isUpdate ? "Update your rating" : "Rate for other guests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        model.closeForm()
                        dismiss()
                    }
                }
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
        }
    }
}
