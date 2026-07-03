// QuickLogSheet.swift — Two-tap fast-log flow from FAB

import SwiftUI
import SwiftData

struct QuickLogSheet: View {
    let park: Park

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @Query private var allRides: [Ride]

    @State private var searchText   = ""
    @State private var pendingRide: Ride? = nil   // first tap: confirm pending
    @State private var loggedRide:  Ride? = nil   // second tap: show success
    @State private var logDate      = Date()

    private var parkRides: [Ride] {
        allRides
            .filter { $0.park == park.rawValue }
            .sorted { $0.order < $1.order }
    }

    private var filteredRides: [Ride] {
        if searchText.isEmpty { return parkRides }
        return parkRides.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.land.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                if let logged = loggedRide {
                    // ── Success state ──────────────────────────────
                    LogSuccessView(ride: logged, accentColor: park.accentColor) {
                        dismiss()
                    }
                    .transition(.scale(scale: 0.85).combined(with: .opacity))
                } else if let pending = pendingRide {
                    // ── Confirm state ──────────────────────────────
                    ConfirmLogView(
                        ride: pending,
                        logDate: $logDate,
                        accentColor: park.accentColor,
                        onConfirm: {
                            confirmLog(ride: pending)
                        },
                        onCancel: {
                            withAnimation(AppMotion.quick) {
                                pendingRide = nil
                            }
                        }
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                } else {
                    // ── Search / pick state ────────────────────────
                    PickRideView(
                        filteredRides: filteredRides,
                        searchText: $searchText,
                        park: park,
                        onSelect: { ride in
                            withAnimation(AppMotion.spring) {
                                pendingRide = ride
                            }
                            AppHaptic.light()
                        }
                    )
                }
            }
            .navigationTitle("Log a Ride")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(park.accentColor)
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    private func confirmLog(ride: Ride) {
        let log = RideLog(date: logDate, ride: ride)
        modelContext.insert(log)
        ride.logs.append(log)
        try? modelContext.save()

        #if DEBUG
        print("✅ [QuickLog] RideLog created — '\(ride.name)' \(logDate)")
        #endif

        // Upsert ParkVisit for the park-local calendar day of the user-selected logDate.
        // park is already typed (let park: Park on QuickLogSheet) — no reverse-lookup needed.
        ParkVisitService.upsertParkVisit(for: park, rideDate: logDate, context: modelContext)

        AppHaptic.success()
        withAnimation(AppMotion.spring) {
            loggedRide = ride
        }
    }
}

// MARK: - Pick Ride Sub-view

private struct PickRideView: View {
    let filteredRides: [Ride]
    @Binding var searchText: String
    let park: Park
    let onSelect: (Ride) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(AppColor.textTertiary)
                TextField("Search rides…", text: $searchText)
                    .autocorrectionDisabled()
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }
            .padding(AppSpacing.md)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.vertical, AppSpacing.md)

            // Ride list
            List {
                ForEach(groupedByLand(filteredRides), id: \.land) { section in
                    Section(header:
                        Text(section.land)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .textCase(nil)
                    ) {
                        ForEach(section.rides) { ride in
                            QuickLogRideRow(ride: ride, accentColor: park.accentColor) {
                                onSelect(ride)
                            }
                            .listRowBackground(AppColor.card)
                            .listRowInsets(EdgeInsets(
                                top: AppSpacing.xs,
                                leading: AppSpacing.screenEdge,
                                bottom: AppSpacing.xs,
                                trailing: AppSpacing.screenEdge
                            ))
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
    }

    private struct LandSection {
        let land: String
        let rides: [Ride]
    }

    private func groupedByLand(_ rides: [Ride]) -> [LandSection] {
        let grouped = Dictionary(grouping: rides) { $0.land }
        return grouped
            .map { LandSection(land: $0.key, rides: $0.value.sorted { $0.order < $1.order }) }
            .sorted { $0.rides.first?.order ?? 0 < $1.rides.first?.order ?? 0 }
    }
}

// MARK: - Quick Log Ride Row

private struct QuickLogRideRow: View {
    let ride: Ride
    let accentColor: Color
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textPrimary)
                    if ride.isRidden {
                        Text("Ridden ×\(ride.rideCount)")
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
                Spacer()
                if ride.isRidden {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(accentColor.opacity(0.6))
                        .font(.subheadline)
                }
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Confirm Log Sub-view

private struct ConfirmLogView: View {
    let ride: Ride
    @Binding var logDate: Date
    let accentColor: Color
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Ride name hero
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(accentColor)
                Text(ride.name)
                    .font(.title2.bold())
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Text(ride.land)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }

            // Date picker
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Text("When did you ride?")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                DatePicker(
                    "",
                    selection: $logDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.compact)
                .labelsHidden()
                .tint(accentColor)
            }
            .padding(AppSpacing.cardPadding)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))

            Spacer()

            // Actions
            VStack(spacing: AppSpacing.sm) {
                Button(action: onConfirm) {
                    Label("Log It!", systemImage: "checkmark")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
                }
                Button("Back to list", action: onCancel)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.bottom, AppSpacing.xl)
    }
}

// MARK: - Log Success Sub-view

private struct LogSuccessView: View {
    let ride: Ride
    let accentColor: Color
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Celebration
            VStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(accentColor.opacity(0.12))
                        .frame(width: 100, height: 100)
                    Image(systemName: "star.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColor.brandGold)
                }
                Text("Logged!")
                    .font(.largeTitle.bold())
                    .foregroundStyle(AppColor.textPrimary)
                Text(ride.name)
                    .font(.title3)
                    .foregroundStyle(AppColor.textSecondary)
                    .multilineTextAlignment(.center)
                if ride.rideCount > 1 {
                    Text("You've ridden this \(ride.rideCount) times total 🎉")
                        .font(.subheadline)
                        .foregroundStyle(accentColor)
                }
            }

            Spacer()

            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(accentColor)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            }
            .padding(.horizontal, AppSpacing.screenEdge)
            .padding(.bottom, AppSpacing.xl)
        }
    }
}
