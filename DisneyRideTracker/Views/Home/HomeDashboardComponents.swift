// HomeDashboardComponents.swift — Premium Home screen components (Phase 3)
//
// Components in this file:
//   CrowdLevel          — Enum classifying park busyness from avg wait time.
//   HomeSectionHeader   — Reusable section title row with optional action button.
//   HomeGreetingHeader  — Time-aware greeting + date line beneath park selector.
//   HomeStatusCard      — Crowd badge + three-stat row + completion bar.
//   HomeBestNextRideCard — Hero recommendation card with Map / Details CTAs.
//   HomeMyDayPreviewCard — Compact My Day checklist preview with see-all footer.
//   HomeMyDayPreviewRow  — Single row inside the My Day preview card.
//   HomeQuickActionsRow  — Three equal action buttons: Map, My Day, Log Ride.
//   HomeQuickActionButton — Individual pressable action tile.

import SwiftUI

// MARK: - CrowdLevel

/// Park busyness level, derived from the mean live wait time across
/// all rideable attractions. Used by HomeStatusCard.
enum CrowdLevel: Equatable {
    case unknown
    case low        // < 20 min avg
    case moderate   // 20–34 min avg
    case busy       // 35–49 min avg
    case packed     // ≥ 50 min avg

    init(averageWait: Int) {
        switch averageWait {
        case 0..<20:  self = .low
        case 20..<35: self = .moderate
        case 35..<50: self = .busy
        default:      self = .packed
        }
    }

    var label: String {
        switch self {
        case .unknown:  return "Checking…"
        case .low:      return "Quiet day"
        case .moderate: return "Moderate"
        case .busy:     return "Busy"
        case .packed:   return "Packed"
        }
    }

    var systemImage: String {
        switch self {
        case .unknown:  return "antenna.radiowaves.left.and.right"
        case .low:      return "leaf.fill"
        case .moderate: return "figure.walk"
        case .busy:     return "person.2.fill"
        case .packed:   return "person.3.fill"
        }
    }

    var color: Color {
        switch self {
        case .unknown:  return AppColor.textTertiary
        case .low:      return AppColor.success
        case .moderate: return AppColor.brandGold
        case .busy:     return AppColor.waitOrange
        case .packed:   return AppColor.error
        }
    }
}

// MARK: - HomeSectionHeader

/// Reusable two-line section header with an optional right-side action button.
/// All parameters after `title` are optional so callers can omit what they
/// don't need without ugly `nil` arguments.
struct HomeSectionHeader: View {
    let title: String
    var subtitle: String?       = nil
    var actionLabel: String?    = nil
    var action: (() -> Void)?   = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)
                if let sub = subtitle {
                    Text(sub)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }
            Spacer()
            if let label = actionLabel, let tap = action {
                Button(label, action: tap)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.brandPrimary)
            }
        }
    }
}

// MARK: - HomeGreetingHeader

/// Time-aware greeting line + date displayed between the park selector and
/// the status card. Keeps the top of the scroll light and personal.
struct HomeGreetingHeader: View {
    let park: Park

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12:  return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<22: return "Good evening"
        default:      return "Ready for magic"
        }
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE, MMMM d"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(Self.dateFormatter.string(from: Date()))
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.5)
            Text(greeting)
                .font(.title2.bold())
                .foregroundStyle(AppColor.textPrimary)
            Text("Ready for \(park.shortName)?")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

// MARK: - HomeStatusCard

/// The main at-a-glance summary card. Shows crowd level, open ride count,
/// average wait, ridden progress, and a thin completion bar.
struct HomeStatusCard: View {
    let park:        Park
    let openCount:   Int
    let totalCount:  Int
    let riddenCount: Int
    let averageWait: Int?
    let crowdLevel:  CrowdLevel

    private var completion: Double {
        guard totalCount > 0 else { return 0 }
        return Double(riddenCount) / Double(totalCount)
    }

    var body: some View {
        VStack(spacing: AppSpacing.md) {

            // ── Top row: crowd badge + "Today" label ──────────────────────
            HStack {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: crowdLevel.systemImage)
                        .font(.caption.weight(.semibold))
                    Text(crowdLevel.label)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(crowdLevel.color)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(crowdLevel.color.opacity(0.12))
                .clipShape(Capsule())

                Spacer()

                Text("Today")
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(AppColor.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.5)
            }

            Divider()

            // ── Stats row: open rides | avg wait | ridden ─────────────────
            HStack(spacing: 0) {
                StatusStatCell(
                    value: openCount > 0 ? "\(openCount)" : "—",
                    label: "Rides open",
                    color: park.accentColor
                )

                Divider().frame(height: 40)

                StatusStatCell(
                    value: averageWait.map { "\($0) min" } ?? "—",
                    label: "Avg wait",
                    color: averageWait
                        .map { AppColor.waitColor(minutes: $0) }
                        ?? AppColor.textTertiary
                )

                Divider().frame(height: 40)

                StatusStatCell(
                    value: totalCount > 0 ? "\(riddenCount)/\(totalCount)" : "—",
                    label: "Ridden",
                    color: AppColor.success
                )
            }

            // ── Completion bar ─────────────────────────────────────────────
            if totalCount > 0 {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(AppColor.skeleton)
                            .frame(height: 6)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [park.accentColor.opacity(0.75), park.accentColor],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: max(6, geo.size.width * completion),
                                height: 6
                            )
                            .animation(AppMotion.standard, value: completion)
                    }
                }
                .frame(height: 6)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

private struct StatusStatCell: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.title3.bold())
                .foregroundStyle(color)
                .minimumScaleFactor(0.75)
                .lineLimit(1)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
                .textCase(.uppercase)
                .tracking(0.3)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - HomeBestNextRideCard

/// Full-width hero card recommending the single best ride to do next.
/// Identifies itself with an internal pill label so it needs no outer
/// section header — it is always the first prominent element after the
/// status card and reads as a natural primary CTA.
struct HomeBestNextRideCard: View {
    let ride:        Ride
    let state:       LiveRideState
    let park:        Park
    let onShowOnMap: () -> Void

    @State private var showDetail = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {

            // ── Header: self-label pill + wait time ───────────────────────
            HStack(alignment: .top) {
                HStack(spacing: AppSpacing.xs) {
                    Image(systemName: "sparkles")
                        .font(.caption2.weight(.bold))
                    Text("Best Next Ride")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(park.accentColor)
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.xs)
                .background(park.accentColor.opacity(0.10))
                .clipShape(Capsule())

                Spacer()

                VStack(alignment: .trailing, spacing: 1) {
                    Text(state.waitDisplay)
                        .font(.title2.bold())
                        .foregroundStyle(state.waitColor)
                    Text("wait")
                        .font(.caption2)
                        .foregroundStyle(AppColor.textTertiary)
                }
            }

            // ── Ride name ─────────────────────────────────────────────────
            Text(ride.name)
                .font(.title3.bold())
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            // ── Location + Lightning Lane ──────────────────────────────────
            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "mappin.circle.fill")
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)
                Text(ride.land)
                    .font(.subheadline)
                    .foregroundStyle(AppColor.textSecondary)

                if state.lightningLaneAvailable {
                    Text("·")
                        .foregroundStyle(AppColor.textTertiary)
                    Image(systemName: "bolt.fill")
                        .font(.caption2)
                        .foregroundStyle(AppColor.brandGold)
                    Text("Lightning Lane")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.brandGoldDeep)
                }
            }

            // ── Action buttons ────────────────────────────────────────────
            HStack(spacing: AppSpacing.sm) {
                Button {
                    AppHaptic.light()
                    onShowOnMap()
                } label: {
                    Label("View on Map", systemImage: "map.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(park.accentColor)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.sm)
                        .background(park.accentColor.opacity(0.10))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    AppHaptic.light()
                    showDetail = true
                } label: {
                    HStack(spacing: 4) {
                        Text("Details")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .foregroundStyle(AppColor.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.sm)
                    .background(AppColor.skeleton.opacity(0.55))
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(AppSpacing.cardPadding)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl)
                .strokeBorder(park.accentColor.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: park.accentColor.opacity(0.10), radius: 14, x: 0, y: 5)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - HomeMyDayPreviewCard

/// Compact My Day preview: up to 4 items (unchecked first) + a see-all footer.
/// Takes pre-computed `previewItems` from the parent so this view itself
/// does not need an @Environment reference to MyDayStore, avoiding
/// double-observation in SwiftUI's @Observable tracking.
struct HomeMyDayPreviewCard: View {
    let previewItems: [MyDayItem]
    let totalCount:   Int
    let onTapItem:    (MyDayItem) -> Void
    let onTapSeeAll:  () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Item rows with interior dividers
            ForEach(Array(previewItems.enumerated()), id: \.element.id) { idx, item in
                HomeMyDayPreviewRow(item: item) { onTapItem(item) }

                if idx < previewItems.count - 1 {
                    Divider()
                        .padding(.leading, 52) // align to text, past icon + gap
                }
            }

            // Footer: "See all N items"
            if totalCount > 0 {
                Divider()

                Button {
                    AppHaptic.light()
                    onTapSeeAll()
                } label: {
                    HStack(spacing: AppSpacing.xs) {
                        Spacer()
                        Text(totalCount == 1 ? "See 1 item" : "See all \(totalCount) items")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(AppColor.brandPrimary)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(AppColor.brandPrimary)
                        Spacer()
                    }
                    .padding(.vertical, AppSpacing.md)
                }
                .buttonStyle(.plain)
            }
        }
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        .shadow(color: .black.opacity(0.06), radius: 6, x: 0, y: 2)
    }
}

// MARK: - HomeMyDayPreviewRow

/// One compact row inside HomeMyDayPreviewCard. Tapping navigates to the
/// map (if it's a ride with a rideId) or to the My Day tab.
private struct HomeMyDayPreviewRow: View {
    let item:   MyDayItem
    let onTap:  () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {

                // Type icon circle
                ZStack {
                    Circle()
                        .fill(item.type.color.opacity(item.isChecked ? 0.07 : 0.12))
                        .frame(width: 32, height: 32)
                    Image(systemName: item.type.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(
                            item.isChecked
                                ? item.type.color.opacity(0.4)
                                : item.type.color
                        )
                }

                // Title + optional land
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(item.isChecked ? .regular : .medium))
                        .foregroundStyle(
                            item.isChecked ? AppColor.textTertiary : AppColor.textPrimary
                        )
                        .strikethrough(item.isChecked, color: AppColor.textTertiary)
                        .lineLimit(1)

                    if let land = item.land {
                        Text(land)
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                    }
                }

                Spacer(minLength: 0)

                // Right accessory: checkmark, time, or chevron
                if item.isChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppColor.success)
                } else if let time = item.formattedTime {
                    Text(time)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textTertiary)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - HomeQuickActionsRow

/// Three equal action tiles: Open Map, My Day, Log Ride.
/// Arranged in a fixed HStack so they're always visible without scrolling.
struct HomeQuickActionsRow: View {
    let park:      Park
    let onOpenMap: () -> Void
    let onMyDay:   () -> Void
    let onLogRide: () -> Void

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            HomeQuickActionButton(
                icon:   "map.fill",
                label:  "Open Map",
                color:  park.accentColor,
                action: { AppHaptic.light(); onOpenMap() }
            )
            HomeQuickActionButton(
                icon:   "checklist",
                label:  "My Day",
                color:  Color.purple,
                action: { AppHaptic.light(); onMyDay() }
            )
            HomeQuickActionButton(
                icon:   "plus.circle.fill",
                label:  "Log Ride",
                color:  AppColor.success,
                action: { onLogRide() }
            )
        }
    }
}

// MARK: - HomeQuickActionButton

/// A single pressable tile for HomeQuickActionsRow.
/// Uses a simultaneous drag gesture to give the press-scale effect without
/// consuming tap events from the enclosing Button.
struct HomeQuickActionButton: View {
    let icon:   String
    let label:  String
    let color:  Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.title2.weight(.medium))
                    .foregroundStyle(color)
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.lg)
            .background(color.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.94 : 1.0)
        .animation(AppMotion.quick, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded   { _ in isPressed = false }
        )
    }
}
