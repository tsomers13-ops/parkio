// DiningRatingSheet.swift — Sheet for entering or editing a personal dining rating.
//
// Captures:
//   • Star rating   (1–5, required)
//   • Favourite     (Bool toggle)
//   • Notes         (optional, ≤ 200 chars with live counter)
//
// On save:
//   • If this is the first rating AND the venue has zero logged visits,
//     automatically inserts a RideLog for today so the venue appears "visited".
//   • lastVisited is derived from Ride.mostRecentDate after any auto-log.
//   • Persisted via DiningRatingStore → UserDefaults JSON.
//
// Ride recommendation logic is completely unaffected — dining venues are
// never candidates for bestNextRide regardless of rating state.

import SwiftUI
import SwiftData

// MARK: - DiningRatingSheet

struct DiningRatingSheet: View {
    let ride: Ride
    let existing: DiningRating?
    let accentColor: Color

    @Environment(DiningRatingStore.self) private var ratingStore
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var rating:     Int
    @State private var isFavorite: Bool
    @State private var notes:      String

    private let maxNotes = 200

    // MARK: - Init

    init(ride: Ride, existing: DiningRating?, accentColor: Color) {
        self.ride        = ride
        self.existing    = existing
        self.accentColor = accentColor
        _rating     = State(initialValue: existing?.rating     ?? 3)
        _isFavorite = State(initialValue: existing?.isFavorite ?? false)
        _notes      = State(initialValue: existing?.notes      ?? "")
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                Form {

                    // ── Stars ──────────────────────────────────────────────────
                    Section {
                        HStack {
                            Spacer()
                            StarRatingView(
                                rating:      $rating,
                                starFont:    .largeTitle,
                                activeColor: accentColor
                            )
                            Spacer()
                        }
                        .padding(.vertical, AppSpacing.sm)
                        .listRowBackground(AppColor.card)
                    } header: {
                        Text("Your Rating")
                    }

                    // ── Favourite toggle ───────────────────────────────────────
                    Section {
                        Toggle(isOn: $isFavorite) {
                            Label {
                                Text("Favourite")
                                    .foregroundStyle(AppColor.textPrimary)
                            } icon: {
                                Image(systemName: "heart.fill")
                                    .foregroundStyle(isFavorite ? AppColor.error : AppColor.textTertiary)
                            }
                        }
                        .tint(AppColor.error)
                        .listRowBackground(AppColor.card)
                    }

                    // ── Notes ──────────────────────────────────────────────────
                    Section {
                        VStack(alignment: .trailing, spacing: AppSpacing.xs) {
                            TextEditor(text: $notes)
                                .frame(minHeight: 80, maxHeight: 160)
                                .scrollContentBackground(.hidden)
                                .foregroundStyle(AppColor.textPrimary)
                                .onChange(of: notes) { _, new in
                                    if new.count > maxNotes {
                                        notes = String(new.prefix(maxNotes))
                                    }
                                }

                            Text("\(notes.count) / \(maxNotes)")
                                .font(.caption2.weight(.medium))
                                .monospacedDigit()
                                .foregroundStyle(
                                    notes.count >= maxNotes
                                        ? AppColor.error
                                        : AppColor.textTertiary
                                )
                        }
                        .listRowBackground(AppColor.card)
                    } header: {
                        Text("Notes (optional)")
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(existing == nil ? "Rate This Location" : "Edit Rating")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .tint(accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { saveRating() }
                        .fontWeight(.semibold)
                        .tint(accentColor)
                }
            }
        }
    }

    // MARK: - Save

    private func saveRating() {
        // Auto-log today as a visit when saving the first rating for an unvisited venue.
        if existing == nil && ride.logs.isEmpty {
            let log = RideLog(date: Date(), ride: ride)
            context.insert(log)
            ride.logs.append(log)
            try? context.save()
        }

        let newRating = DiningRating(
            attractionID: ride.id,
            rating:       rating,
            isFavorite:   isFavorite,
            notes:        notes.trimmingCharacters(in: .whitespacesAndNewlines),
            lastVisited:  ride.mostRecentDate,  // reflects any auto-log above
            dateRated:    Date()
        )
        ratingStore.save(newRating)
        AppHaptic.success()
        dismiss()
    }
}
