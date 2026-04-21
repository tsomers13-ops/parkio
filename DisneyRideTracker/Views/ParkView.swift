// ParkView.swift — Full ride list for a park (Phase 2 design system)
// Used as a "See all" destination pushed from HomeView.

import SwiftUI
import SwiftData

enum ParkViewMode: String, CaseIterable, Identifiable {
    case byWait  = "Wait Times"
    case byLand  = "By Land"
    case unridden = "Unridden"
    var id: String { rawValue }
}

struct ParkView: View {
    let park: Park

    @Query private var allRides: [Ride]
    @Environment(WaitTimeViewModel.self) private var waitTimeVM

    @State private var viewMode: ParkViewMode = .byWait
    @State private var searchText: String = ""
    @State private var selectedRide: Ride?

    private var parkRides: [Ride] {
        allRides.filter { $0.park == park.rawValue }
    }

    private var filteredRides: [Ride] {
        guard !searchText.isEmpty else { return parkRides }
        return parkRides.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Stats header
                StatsHeaderView(park: park, rides: parkRides)

                // Mode picker
                Picker("View", selection: $viewMode) {
                    ForEach(ParkViewMode.allCases) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, AppSpacing.screenEdge)
                .padding(.vertical, AppSpacing.sm)

                // Content
                Group {
                    switch viewMode {
                    case .byWait:
                        ByWaitListView(
                            park:        park,
                            rides:       filteredRides,
                            waitTimeVM:  waitTimeVM,
                            onTap:       { selectedRide = $0 }
                        )
                    case .byLand:
                        ByLandListView(
                            park:       park,
                            rides:      filteredRides,
                            waitTimeVM: waitTimeVM,
                            onTap:      { selectedRide = $0 }
                        )
                    case .unridden:
                        UnriddenListView(
                            rides:      filteredRides,
                            accentColor: park.accentColor,
                            waitTimeVM:  waitTimeVM,
                            onTap:      { selectedRide = $0 }
                        )
                    }
                }
            }
        }
        .navigationTitle(park.displayName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if waitTimeVM.isLoadingActivePark {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(0.75)
                        .tint(park.accentColor)
                } else if waitTimeVM.hasDataForActivePark {
                    Text(waitTimeVM.lastUpdatedString)
                        .font(.caption2)
                        .foregroundStyle(
                            waitTimeVM.isStale ? AppColor.warning : AppColor.textTertiary
                        )
                }
            }
        }
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .automatic),
            prompt: "Search rides"
        )
        .refreshable {
            await waitTimeVM.refresh()
        }
        .sheet(item: $selectedRide) { ride in
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - By Wait Time (default tab — all rides sorted by live wait)

private struct ByWaitListView: View {
    let park: Park
    let rides: [Ride]
    let waitTimeVM: WaitTimeViewModel
    let onTap: (Ride) -> Void

    private func liveState(for ride: Ride) -> LiveRideState? {
        waitTimeVM.liveState(matching: ride)
    }

    /// Sort: operating rides by ascending wait first, then closed/down, then unknown.
    private var sortedRides: [Ride] {
        rides.sorted { lhs, rhs in
            let lState = liveState(for: lhs)
            let rState = liveState(for: rhs)

            let lRideable  = lState?.status.isRideable ?? false
            let rRideable  = rState?.status.isRideable ?? false

            if lRideable != rRideable { return lRideable }   // open rides first

            let lWait = lState?.waitMinutes ?? Int.max
            let rWait = rState?.waitMinutes ?? Int.max
            return lWait < rWait
        }
    }

    var body: some View {
        List {
            ForEach(sortedRides) { ride in
                RideRow(ride: ride, liveState: liveState(for: ride), accentColor: park.accentColor)
                    .contentShape(Rectangle())
                    .onTapGesture { onTap(ride) }
                    .listRowBackground(AppColor.card)
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - By Land

private struct ByLandListView: View {
    let park: Park
    let rides: [Ride]
    let waitTimeVM: WaitTimeViewModel
    let onTap: (Ride) -> Void

    private func liveState(for ride: Ride) -> LiveRideState? {
        waitTimeVM.liveState(matching: ride)
    }

    private func ridesIn(land: String) -> [Ride] {
        rides
            .filter { $0.land == land }
            .sorted { lhs, rhs in
                let lWait = liveState(for: lhs)?.waitMinutes ?? (lhs.order + 1000)
                let rWait = liveState(for: rhs)?.waitMinutes ?? (rhs.order + 1000)
                return lWait < rWait
            }
    }

    var body: some View {
        List {
            ForEach(park.lands, id: \.self) { land in
                let landRides = ridesIn(land: land)
                if !landRides.isEmpty {
                    Section(header:
                        Text(land)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(AppColor.textSecondary)
                            .textCase(nil)
                    ) {
                        ForEach(landRides) { ride in
                            RideRow(ride: ride, liveState: liveState(for: ride), accentColor: park.accentColor)
                                .contentShape(Rectangle())
                                .onTapGesture { onTap(ride) }
                                .listRowBackground(AppColor.card)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .scrollContentBackground(.hidden)
    }
}

// MARK: - Unridden List

private struct UnriddenListView: View {
    let rides: [Ride]
    let accentColor: Color
    let waitTimeVM: WaitTimeViewModel
    let onTap: (Ride) -> Void

    private func liveState(for ride: Ride) -> LiveRideState? {
        waitTimeVM.liveState(matching: ride)
    }

    private var unridden: [Ride] {
        rides
            .filter { !$0.isRidden }
            .sorted { lhs, rhs in
                let lWait = liveState(for: lhs)?.waitMinutes ?? (lhs.order + 1000)
                let rWait = liveState(for: rhs)?.waitMinutes ?? (rhs.order + 1000)
                return lWait < rWait
            }
    }

    var body: some View {
        Group {
            if unridden.isEmpty {
                EmptyStateView(
                    icon: "checkmark.seal.fill",
                    title: "You've ridden everything!",
                    message: "Every attraction in this park has at least one logged date."
                )
            } else {
                List {
                    ForEach(unridden) { ride in
                        RideRow(ride: ride, liveState: liveState(for: ride), accentColor: accentColor)
                            .contentShape(Rectangle())
                            .onTapGesture { onTap(ride) }
                            .listRowBackground(AppColor.card)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}

// MARK: - Ride Row

struct RideRow: View {
    let ride: Ride
    var liveState: LiveRideState? = nil
    let accentColor: Color

    var body: some View {
        HStack(spacing: AppSpacing.md) {

            // Ridden indicator
            Image(systemName: ride.isRidden ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundStyle(ride.isRidden ? accentColor : AppColor.textTertiary)
                .accessibilityLabel(ride.isRidden ? "Ridden" : "Not ridden")

            // Name + subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(ride.name)
                    .font(.subheadline.weight(ride.isRidden ? .regular : .medium))
                    .foregroundStyle(ride.isRidden ? AppColor.textSecondary : AppColor.textPrimary)
                HStack(spacing: AppSpacing.xs) {
                    if ride.rideCount > 0 {
                        Text("\(ride.rideCount)× ridden")
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                    if let date = ride.mostRecentDate {
                        if ride.rideCount > 0 {
                            Text("·").font(.caption).foregroundStyle(AppColor.textTertiary)
                        }
                        Text(date, style: .date)
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }
            }

            Spacer()

            // Live wait badge
            if let live = liveState {
                if live.status.isRideable {
                    HStack(spacing: 3) {
                        Text(live.waitDisplay)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(live.waitColor)

                        if live.trend == .rising || live.trend == .falling {
                            Image(systemName: live.trend.systemImage)
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(
                                    live.trend == .rising ? AppColor.error : AppColor.success
                                )
                        }
                    }
                    .padding(.horizontal, AppSpacing.sm)
                    .padding(.vertical, 4)
                    .background(live.waitColor.opacity(0.12))
                    .clipShape(Capsule())
                } else {
                    Text(live.status.displayLabel)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textTertiary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, 4)
                        .background(AppColor.skeleton)
                        .clipShape(Capsule())
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textTertiary)
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

// MARK: - Empty State

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String

    init(icon: String = "sparkles", title: String, message: String) {
        self.icon = icon
        self.title = title
        self.message = message
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundStyle(AppColor.textTertiary)
            Text(title)
                .font(.headline)
                .foregroundStyle(AppColor.textPrimary)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xxl)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
}
