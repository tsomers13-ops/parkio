// ProfileView.swift — Profile & settings tab (Phase 2 design system)

import SwiftUI
import SwiftData

// File-level so ParkProgressRow (a separate struct) can reference it.
fileprivate struct ParkStat: Identifiable {
    let park: Park
    let ridden: Int
    let total: Int
    var id: String { park.id }
    var completion: Double { total > 0 ? Double(ridden) / Double(total) : 0 }
}

struct ProfileView: View {
    @Query private var allRides: [Ride]
    @Query private var allLogs: [RideLog]

    @State private var showResetAlert = false
    @Environment(\.modelContext) private var modelContext

    private var parkStats: [ParkStat] {
        Park.allCases.map { park in
            let rides = allRides.filter { $0.park == park.rawValue }
            return ParkStat(park: park, ridden: rides.filter(\.isRidden).count, total: rides.count)
        }
    }

    private var totalRideOns: Int { allLogs.count }
    private var totalRidden: Int { allRides.filter(\.isRidden).count }
    private var totalRides: Int { allRides.count }
    private var overallCompletion: Double {
        totalRides > 0 ? Double(totalRidden) / Double(totalRides) : 0
    }

    private var firstLogDate: Date? {
        allLogs.map(\.date).min()
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                List {
                    // ── Overall stats ─────────────────────────────
                    Section {
                        OverallStatsCard(
                            rideOns: totalRideOns,
                            ridden: totalRidden,
                            total: totalRides,
                            completion: overallCompletion,
                            since: firstLogDate
                        )
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                    }

                    // ── Per-park progress ─────────────────────────
                    Section(header:
                        Text("By Park")
                            .foregroundStyle(AppColor.textSecondary)
                            .textCase(nil)
                    ) {
                        ForEach(parkStats) { stat in
                            ParkProgressRow(stat: stat)
                                .listRowBackground(AppColor.card)
                        }
                    }

                    // ── Annual passholder tools ─────────────────────
                    Section(header:
                        Text("Annual Passholder")
                            .foregroundStyle(AppColor.textSecondary)
                            .textCase(nil)
                    ) {
                        NavigationLink {
                            ParkVisitsView()
                        } label: {
                            ProfileInfoRow(
                                icon: "ticket.fill",
                                label: "Park Visits",
                                value: "This Year"
                            )
                        }
                    }
                    .listRowBackground(AppColor.card)

                    // ── About ─────────────────────────────────────
                    Section(header:
                        Text("About")
                            .foregroundStyle(AppColor.textSecondary)
                            .textCase(nil)
                    ) {
                        ProfileInfoRow(icon: "info.circle", label: "Version", value: "1.0.0")
                        ProfileInfoRow(icon: "star.fill", label: "Design System", value: "Phase 2")
                        ProfileInfoRow(icon: "mappin.and.ellipse", label: "Parks", value: "6 parks, \(totalRides) rides")
                    }
                    .listRowBackground(AppColor.card)

                    // ── Danger zone ───────────────────────────────
                    Section {
                        Button(role: .destructive) {
                            showResetAlert = true
                        } label: {
                            Label("Reset All Ride Logs", systemImage: "trash")
                        }
                    }
                    .listRowBackground(AppColor.card)
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Reset All Logs?", isPresented: $showResetAlert) {
                Button("Reset", role: .destructive) { resetLogs() }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("This will permanently delete all \(totalRideOns) ride log entries. Your ride list is preserved.")
            }
        }
    }

    private func resetLogs() {
        for log in allLogs {
            modelContext.delete(log)
        }
        try? modelContext.save()
        AppHaptic.warning()
    }
}

// MARK: - Overall Stats Card

private struct OverallStatsCard: View {
    let rideOns: Int
    let ridden: Int
    let total: Int
    let completion: Double
    let since: Date?

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    var body: some View {
        VStack(spacing: AppSpacing.lg) {
            // Big number
            VStack(spacing: AppSpacing.xs) {
                Text("\(rideOns)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(AppColor.brandPrimary)
                Text("Total Ride-Ons")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                if let since = since {
                    Text("since \(Self.dateFormatter.string(from: since))")
                        .font(.caption)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }

            // Stats row
            HStack {
                MiniStat(value: "\(ridden)", label: "Unique Rides")
                Divider().frame(height: 28)
                MiniStat(value: "\(total - ridden)", label: "To Go")
                Divider().frame(height: 28)
                MiniStat(value: "\(Int(completion * 100))%", label: "Complete")
            }

            // Progress bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.skeleton).frame(height: 10)
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppColor.brandPrimary.opacity(0.7), AppColor.brandPrimary],
                                startPoint: .leading, endPoint: .trailing
                            )
                        )
                        .frame(width: geo.size.width * completion, height: 10)
                }
            }
            .frame(height: 10)
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, AppSpacing.sm)
    }
}

private struct MiniStat: View {
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

// MARK: - Park Progress Row

private struct ParkProgressRow: View {
    let stat: ParkStat

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: stat.park.systemImageName)
                    .font(.subheadline)
                    .foregroundStyle(stat.park.accentColor)
                    .frame(width: 20)
                Text(stat.park.shortName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                Spacer()
                Text("\(stat.ridden) / \(stat.total)")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                Text("\(Int(stat.completion * 100))%")
                    .font(.caption.bold())
                    .foregroundStyle(stat.park.accentColor)
                    .frame(width: 32, alignment: .trailing)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColor.skeleton).frame(height: 5)
                    Capsule()
                        .fill(stat.park.accentColor)
                        .frame(width: geo.size.width * stat.completion, height: 5)
                }
            }
            .frame(height: 5)
        }
        .padding(.vertical, AppSpacing.sm)
    }
}

// MARK: - Info Row

private struct ProfileInfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.subheadline)
                .foregroundStyle(AppColor.brandPrimary)
                .frame(width: 24)
            Text(label)
                .foregroundStyle(AppColor.textPrimary)
            Spacer()
            Text(value)
                .foregroundStyle(AppColor.textSecondary)
                .font(.subheadline)
        }
    }
}

#Preview {
    ProfileView()
        .modelContainer(for: [Ride.self, RideLog.self], inMemory: true)
}
