// ParkVisitsView.swift — Annual passholder park visit tracker.

import SwiftUI
import SwiftData

struct ParkVisitsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ParkVisit.visitDate, order: .reverse) private var visits: [ParkVisit]

    @State private var selectedYear = Calendar.current.component(.year, from: Date())
    @State private var showingAddVisit = false

    private var selectedYearVisits: [ParkVisit] {
        visits.filter { Calendar.current.component(.year, from: $0.visitDate) == selectedYear }
    }

    private var availableYears: [Int] {
        let years = Set(visits.map { Calendar.current.component(.year, from: $0.visitDate) })
            .union([Calendar.current.component(.year, from: Date())])
        return years.sorted(by: >)
    }

    private var parkStats: [ParkVisitStat] {
        Park.allCases.map { park in
            let parkVisits = selectedYearVisits.filter { $0.parkId == park.backendId }
            return ParkVisitStat(
                park: park,
                count: parkVisits.count,
                lastVisit: parkVisits.map(\.visitDate).max()
            )
        }
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            List {
                Section {
                    ParkVisitYearPicker(
                        selectedYear: $selectedYear,
                        availableYears: availableYears
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(
                        top: AppSpacing.sm,
                        leading: AppSpacing.screenEdge,
                        bottom: AppSpacing.sm,
                        trailing: AppSpacing.screenEdge
                    ))

                    ParkVisitSummaryCard(
                        year: selectedYear,
                        totalVisits: selectedYearVisits.count
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                Section {
                    ForEach(parkStats) { stat in
                        ParkVisitStatRow(stat: stat)
                            .listRowBackground(AppColor.card)
                    }
                } header: {
                    Text("By Park")
                        .foregroundStyle(AppColor.textSecondary)
                        .textCase(nil)
                }

                Section {
                    if selectedYearVisits.isEmpty {
                        EmptyParkVisitsRow(year: selectedYear)
                            .listRowBackground(AppColor.card)
                    } else {
                        ForEach(selectedYearVisits.prefix(20)) { visit in
                            ParkVisitHistoryRow(visit: visit)
                                .listRowBackground(AppColor.card)
                                .swipeActions(edge: .trailing) {
                                    Button(role: .destructive) {
                                        delete(visit)
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    }
                } header: {
                    Text("Recent Visits")
                        .foregroundStyle(AppColor.textSecondary)
                        .textCase(nil)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
        }
        .navigationTitle("Park Visits")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddVisit = true
                } label: {
                    Label("Add Visit", systemImage: "plus.circle.fill")
                }
            }
        }
        .sheet(isPresented: $showingAddVisit) {
            AddParkVisitSheet(defaultDate: defaultAddDate) { park, date in
                addVisit(park: park, date: date)
            }
        }
    }

    private var defaultAddDate: Date {
        let currentYear = Calendar.current.component(.year, from: Date())
        guard selectedYear != currentYear else { return Date() }

        var components = DateComponents()
        components.year = selectedYear
        components.month = 1
        components.day = 1
        return Calendar.current.date(from: components) ?? Date()
    }

    private func addVisit(park: Park, date: Date) {
        // Normalize to park-local start-of-day so manual visits group correctly
        // with auto-created (rideLog) visits on the same calendar day.
        let localDay = ParkVisitService.parkLocalDay(for: date, park: park)
        let visit = ParkVisit(
            parkId:    park.backendId,
            visitDate: localDay,
            source:    "manual"
        )
        modelContext.insert(visit)
        try? modelContext.save()
        selectedYear = Calendar.current.component(.year, from: localDay)
        AppHaptic.success()
    }

    private func delete(_ visit: ParkVisit) {
        modelContext.delete(visit)
        try? modelContext.save()
        AppHaptic.warning()
    }
}

private struct ParkVisitStat: Identifiable {
    let park: Park
    let count: Int
    let lastVisit: Date?

    var id: String { park.backendId }
}

private struct ParkVisitYearPicker: View {
    @Binding var selectedYear: Int
    let availableYears: [Int]

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Label("Year", systemImage: "calendar")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)

            Spacer()

            Picker("Year", selection: $selectedYear) {
                ForEach(availableYears, id: \.self) { year in
                    Text(String(year)).tag(year)
                }
            }
            .pickerStyle(.menu)
            .tint(AppColor.brandPrimary)
        }
        .padding(AppSpacing.cardPadding)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
    }
}

private struct ParkVisitSummaryCard: View {
    let year: Int
    let totalVisits: Int

    var body: some View {
        VStack(spacing: AppSpacing.md) {
            Image(systemName: "ticket.fill")
                .font(.system(size: 34, weight: .semibold))
                .foregroundStyle(AppColor.brandPrimary)

            Text("\(totalVisits)")
                .font(.system(size: 64, weight: .bold, design: .rounded))
                .foregroundStyle(AppColor.textPrimary)
                .contentTransition(.numericText())

            VStack(spacing: AppSpacing.xs) {
                Text("Total Park Visits")
                    .font(.headline)
                    .foregroundStyle(AppColor.textPrimary)
                Text("in \(String(year))")
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(AppSpacing.xl)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
        .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
        .padding(.horizontal, AppSpacing.screenEdge)
        .padding(.vertical, AppSpacing.sm)
        .animation(AppMotion.standard, value: totalVisits)
    }
}

private struct ParkVisitStatRow: View {
    let stat: ParkVisitStat

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: stat.park.systemImageName)
                .font(.headline)
                .foregroundStyle(stat.park.accentColor)
                .frame(width: 28, height: 28)
                .background(stat.park.accentBackground, in: Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(stat.park.displayName)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.textPrimary)
                    .lineLimit(1)
                Text(lastVisitText)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            Text("\(stat.count)")
                .font(.title3.weight(.bold))
                .foregroundStyle(stat.count == 0 ? AppColor.textTertiary : stat.park.accentColor)
                .contentTransition(.numericText())
        }
        .padding(.vertical, AppSpacing.sm)
    }

    private var lastVisitText: String {
        guard let lastVisit = stat.lastVisit else { return "No visits this year" }
        return "Last visit \(Self.dateFormatter.string(from: lastVisit))"
    }
}

private struct ParkVisitHistoryRow: View {
    let visit: ParkVisit

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private var park: Park? {
        Park.fromBackendId(visit.parkId)
    }

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Circle()
                .fill(park?.accentColor ?? AppColor.textTertiary)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(park?.displayName ?? visit.parkId)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                Text(Self.dateFormatter.string(from: visit.visitDate))
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct EmptyParkVisitsRow: View {
    let year: Int

    var body: some View {
        VStack(spacing: AppSpacing.sm) {
            Image(systemName: "calendar.badge.plus")
                .font(.system(size: 32))
                .foregroundStyle(AppColor.textTertiary)
            Text("No park visits logged for \(String(year)).")
                .font(.subheadline.weight(.medium))
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            Text("Tap the + button to add your first visit.")
                .font(.caption)
                .foregroundStyle(AppColor.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppSpacing.xl)
    }
}

private struct AddParkVisitSheet: View {
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPark: Park = .magicKingdom
    @State private var visitDate: Date

    let onSave: (Park, Date) -> Void

    init(defaultDate: Date, onSave: @escaping (Park, Date) -> Void) {
        _visitDate = State(initialValue: defaultDate)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Park", selection: $selectedPark) {
                        ForEach(Park.allCases) { park in
                            Label(park.displayName, systemImage: park.systemImageName)
                                .tag(park)
                        }
                    }

                    DatePicker(
                        "Visit Date",
                        selection: $visitDate,
                        displayedComponents: [.date]
                    )
                }
            }
            .navigationTitle("Add Park Visit")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        onSave(selectedPark, visitDate)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    NavigationStack {
        ParkVisitsView()
    }
    .modelContainer(for: [ParkVisit.self], inMemory: true)
}
