// RideDetailView.swift — Attraction detail sheet (Phase 2 design system)

import SwiftUI
import SwiftData

struct RideDetailView: View {
    @Bindable var ride: Ride

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate: Date = Date()

    /// Accent colour derived from the ride's park — no external injection needed.
    private var accentColor: Color {
        Park(rawValue: ride.park)?.accentColor ?? AppColor.brandPrimary
    }

    // MARK: - Type helpers

    /// The semantic type of this attraction, resolved from master data.
    private var attractionType: AttractionType {
        RideMasterData.typeByStableID[ride.id] ?? .ride
    }

    /// Navigation bar title — reflects the kind of attraction.
    private var detailTitle: String {
        switch attractionType {
        case .characterMeet:                              return "Character Experience"
        case .show, .walkthrough:                         return "Show"
        case .ride, .transport, .future:                  return "Ride"
        case .quickService, .snackStand, .tableService,
             .lounge, .festivalBooth:                     return "Dining"
        }
    }

    /// Past-tense action word used in the hero badge and section headers.
    /// Rides: "Ridden" · Shows & Characters: "Visited"
    private var visitedVerb: String {
        switch attractionType {
        case .ride, .transport, .future: return "Ridden"
        default:                         return "Visited"
        }
    }

    /// Section header for the date-logging section.
    private var logSectionTitle: String {
        switch attractionType {
        case .characterMeet:                              return "Log a character visit"
        case .show, .walkthrough:                         return "Log a show visit"
        case .ride, .transport, .future:                  return "Log a ride date"
        case .quickService, .snackStand, .tableService,
             .lounge, .festivalBooth:                     return "Log a visit"
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                List {
                    // ── Hero header ───────────────────────────────
                    Section {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text(ride.name)
                                .font(.title2.bold())
                                .foregroundStyle(AppColor.textPrimary)
                            Text("\(ride.park) · \(ride.land)")
                                .font(.subheadline)
                                .foregroundStyle(AppColor.textSecondary)

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: ride.isRidden ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(ride.isRidden ? AppColor.success : AppColor.textTertiary)
                                Text(ride.isRidden
                                     ? "\(visitedVerb) \(ride.rideCount)×"
                                     : "Not yet \(visitedVerb.lowercased())")
                                    .font(.callout)
                                    .foregroundStyle(AppColor.textSecondary)
                            }
                            .padding(.top, 2)
                        }
                        .padding(.vertical, AppSpacing.sm)
                    }
                    .listRowBackground(AppColor.card)

                    // ── My Rating (dining only) ──────────────────
                    if attractionType.isDining {
                        DiningRatingSection(ride: ride, accentColor: accentColor)
                    }

                    // ── Log a visit ──────────────────────────────
                    Section(logSectionTitle) {
                        DatePicker(
                            "Date",
                            selection: $selectedDate,
                            in: ...Date(),
                            displayedComponents: [.date, .hourAndMinute]
                        )
                        .datePickerStyle(.graphical)
                        .tint(accentColor)

                        Button(action: logDate) {
                            Label("Add date", systemImage: "plus.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(accentColor)
                    }
                    .listRowBackground(AppColor.card)

                    // ── Logged dates ──────────────────────────────
                    Section("Logged dates") {
                        if ride.logs.isEmpty {
                            Text("No dates logged yet.")
                                .foregroundStyle(AppColor.textTertiary)
                        } else {
                            ForEach(ride.sortedLogs) { log in
                                HStack {
                                    Image(systemName: "calendar")
                                        .foregroundStyle(accentColor)
                                    Text(log.date, style: .date)
                                        .foregroundStyle(AppColor.textPrimary)
                                    Spacer()
                                    Text(log.date, style: .time)
                                        .font(.caption)
                                        .foregroundStyle(AppColor.textSecondary)
                                }
                            }
                            .onDelete(perform: deleteLogs)
                        }
                    }
                    .listRowBackground(AppColor.card)

                    // ── Danger zone ───────────────────────────────
                    if ride.isRidden {
                        Section {
                            Button(role: .destructive, action: markUnridden) {
                                Label("Clear all logs (mark unridden)", systemImage: "arrow.counterclockwise")
                            }
                        }
                        .listRowBackground(AppColor.card)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(detailTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .tint(accentColor)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: toggleRidden) {
                        Image(systemName: ride.isRidden ? "checkmark.circle.fill" : "circle")
                    }
                    .tint(accentColor)
                    .accessibilityLabel(ride.isRidden
                                        ? "Mark as not \(visitedVerb.lowercased())"
                                        : "Mark \(visitedVerb.lowercased()) today")
                }
            }
        }
    }

    // MARK: - Actions

    private func logDate() {
        let log = RideLog(date: selectedDate, ride: ride)
        context.insert(log)
        ride.logs.append(log)
        try? context.save()
        AppHaptic.success()
    }

    private func deleteLogs(at offsets: IndexSet) {
        let sorted = ride.sortedLogs
        for index in offsets {
            let log = sorted[index]
            context.delete(log)
            if let i = ride.logs.firstIndex(where: { $0.persistentModelID == log.persistentModelID }) {
                ride.logs.remove(at: i)
            }
        }
        try? context.save()
    }

    private func toggleRidden() {
        if ride.isRidden {
            markUnridden()
        } else {
            let log = RideLog(date: Date(), ride: ride)
            context.insert(log)
            ride.logs.append(log)
            try? context.save()
            AppHaptic.success()
        }
    }

    private func markUnridden() {
        for log in ride.logs {
            context.delete(log)
        }
        ride.logs.removeAll()
        try? context.save()
    }
}
