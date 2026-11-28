// LogParkDaySheet.swift — Compact confirmation sheet for logging a park day.
//
// Shared between HomeView ("Log park day" button) and ParkVisitsView (+ toolbar).
// Idempotent: a second tap for the same park+day shows "Already logged" feedback
// instead of inserting a duplicate row.

import SwiftUI
import SwiftData

struct LogParkDaySheet: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss)      private var dismiss

    @State private var selectedPark: Park?
    @State private var visitDate:    Date
    @State private var outcome:      ManualVisitOutcome?

    let onSave: (Park, Date) -> Void

    init(
        defaultPark: Park?,
        defaultDate: Date = Date(),
        onSave: @escaping (Park, Date) -> Void = { _, _ in }
    ) {
        _selectedPark = State(initialValue: defaultPark)
        _visitDate    = State(initialValue: defaultDate)
        self.onSave   = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Park", selection: $selectedPark) {
                        Text("Select a park…")
                            .tag(Optional<Park>.none)
                        ForEach(Park.allCases) { park in
                            Label(park.displayName, systemImage: park.systemImageName)
                                .tag(Optional(park))
                        }
                    }
                    .accessibilityIdentifier("parkio.logParkDay.parkPicker")

                    DatePicker(
                        "Date",
                        selection: $visitDate,
                        in: ...Date(),
                        displayedComponents: [.date]
                    )
                }

                if outcome == .alreadyLogged {
                    Section {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Already logged for this day")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .accessibilityIdentifier("parkio.logParkDay.alreadyLogged")
                    }
                }

                if outcome == .saveFailed {
                    Section {
                        HStack(spacing: AppSpacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundStyle(.orange)
                            Text("Could not save — please try again")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)
                        }
                        .accessibilityIdentifier("parkio.logParkDay.saveFailed")
                    }
                }
            }
            .navigationTitle("Log Park Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if outcome == .alreadyLogged {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    } else {
                        Button("Log") { save() }
                            .fontWeight(.semibold)
                            .disabled(selectedPark == nil)
                            .accessibilityIdentifier("parkio.logParkDay.logButton")
                    }
                }
            }
        }
        .presentationDetents([.medium])
        .accessibilityIdentifier("parkio.logParkDay.sheet")
    }

    private func save() {
        guard let park = selectedPark else { return }
        let result = ParkVisitService.saveManualVisit(for: park, date: visitDate, context: modelContext)
        outcome = result
        switch result {
        case .created:
            AppHaptic.success()
            onSave(park, visitDate)
            dismiss()
        case .alreadyLogged:
            AppHaptic.warning()
        case .saveFailed:
            // Stay on sheet so the user can retry; the error banner is shown above.
            AppHaptic.warning()
        }
    }
}
