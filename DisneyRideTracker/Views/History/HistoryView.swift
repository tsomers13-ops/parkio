// HistoryView.swift — Global ride history tab (Phase 2 design system)

import SwiftUI
import SwiftData

struct HistoryView: View {
    @Query(sort: \RideLog.date, order: .reverse) private var allLogs: [RideLog]
    @Query private var allRides: [Ride]

    @State private var filterPark: Park? = nil
    @State private var searchText = ""

    private var filteredLogs: [RideLog] {
        allLogs.filter { log in
            guard let ride = log.ride else { return false }
            let parkMatch = filterPark == nil || ride.park == filterPark?.rawValue
            let searchMatch = searchText.isEmpty ||
                ride.name.localizedCaseInsensitiveContains(searchText) ||
                ride.land.localizedCaseInsensitiveContains(searchText) ||
                ride.park.localizedCaseInsensitiveContains(searchText)
            return parkMatch && searchMatch
        }
    }

    // Group logs by calendar day
    private var groupedLogs: [(date: Date, logs: [RideLog])] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: filteredLogs) { log in
            cal.startOfDay(for: log.date)
        }
        return grouped
            .map { (date: $0.key, logs: $0.value.sorted { $0.date > $1.date }) }
            .sorted { $0.date > $1.date }
    }

    private var totalRideOns: Int { allLogs.count }
    private var uniqueRides: Int { Set(allLogs.compactMap { $0.ride?.id }).count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    // ── Filter strip ──────────────────────────────
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: AppSpacing.sm) {
                            FilterChip(
                                label: "All Parks",
                                isSelected: filterPark == nil,
                                color: AppColor.textSecondary
                            ) {
                                withAnimation(AppMotion.quick) { filterPark = nil }
                                AppHaptic.selection()
                            }
                            ForEach(Park.allCases) { park in
                                FilterChip(
                                    label: park.shortName,
                                    isSelected: filterPark == park,
                                    color: park.accentColor
                                ) {
                                    withAnimation(AppMotion.quick) {
                                        filterPark = filterPark == park ? nil : park
                                    }
                                    AppHaptic.selection()
                                }
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenEdge)
                        .padding(.vertical, AppSpacing.md)
                    }

                    // ── Stats banner ──────────────────────────────
                    HStack(spacing: 0) {
                        HistoryStatCell(value: "\(totalRideOns)", label: "Total Ride-Ons")
                        Divider().frame(height: 32)
                        HistoryStatCell(value: "\(uniqueRides)", label: "Unique Rides")
                        Divider().frame(height: 32)
                        HistoryStatCell(
                            value: "\(allRides.filter(\.isRidden).count)",
                            label: "of \(allRides.count) ridden"
                        )
                    }
                    .padding(.vertical, AppSpacing.md)
                    .background(AppColor.card)
                    .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)

                    // ── Log list ──────────────────────────────────
                    if filteredLogs.isEmpty {
                        Spacer()
                        VStack(spacing: AppSpacing.lg) {
                            Image(systemName: "clock.badge.questionmark")
                                .font(.system(size: 48))
                                .foregroundStyle(AppColor.textTertiary)
                            Text(allLogs.isEmpty ? "No rides logged yet." : "No results.")
                                .font(.headline)
                                .foregroundStyle(AppColor.textSecondary)
                            if allLogs.isEmpty {
                                Text("Tap the + button on the Home tab to log your first ride.")
                                    .font(.subheadline)
                                    .foregroundStyle(AppColor.textTertiary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, AppSpacing.xl)
                            }
                        }
                        Spacer()
                    } else {
                        List {
                            ForEach(groupedLogs, id: \.date) { group in
                                Section(header:
                                    Text(group.date, style: .date)
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(AppColor.textSecondary)
                                        .textCase(nil)
                                ) {
                                    ForEach(group.logs, id: \.date) { log in
                                        if let ride = log.ride {
                                            HistoryLogRow(log: log, ride: ride)
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
                        }
                        .listStyle(.insetGrouped)
                        .scrollContentBackground(.hidden)
                        .searchable(text: $searchText, prompt: "Search rides…")
                    }
                }
            }
            .navigationTitle("History")
            .navigationBarTitleDisplayMode(.large)
        }
    }
}

// MARK: - Filter Chip

private struct FilterChip: View {
    let label: String
    let isSelected: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .foregroundStyle(isSelected ? .white : color)
                .background(isSelected ? color : color.opacity(0.10))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Stat Cell

private struct HistoryStatCell: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(AppColor.textPrimary)
            Text(label)
                .font(.caption2)
                .foregroundStyle(AppColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - History Log Row

private struct HistoryLogRow: View {
    let log: RideLog
    let ride: Ride

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.timeStyle = .short
        f.dateStyle = .none
        return f
    }()

    private var park: Park? { Park(rawValue: ride.park) }

    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
            AppHaptic.light()
        } label: {
            HStack(spacing: AppSpacing.md) {
                // Park color dot
                Circle()
                    .fill(park?.accentColor ?? AppColor.textTertiary)
                    .frame(width: 10, height: 10)

                VStack(alignment: .leading, spacing: 2) {
                    Text(ride.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textPrimary)
                    HStack(spacing: AppSpacing.xs) {
                        Text(ride.park)
                            .font(.caption)
                            .foregroundStyle(park?.accentColor ?? AppColor.textTertiary)
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                        Text(ride.land)
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Spacer()

                Text(Self.timeFormatter.string(from: log.date))
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)

                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textTertiary)
            }
            .padding(.vertical, AppSpacing.xs)
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

#Preview {
    HistoryView()
        .modelContainer(for: [Ride.self, RideLog.self], inMemory: true)
}
