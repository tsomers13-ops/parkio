// HomeDashboardComponents.swift — Home screen cards and compact rows.

import SwiftUI
import CoreLocation

// MARK: - CrowdLevel

enum CrowdLevel: Equatable {
    case unknown
    case low
    case moderate
    case busy
    case packed

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
        case .unknown:  return "Checking"
        case .low:      return "Light"
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
        case .moderate: return AppColor.brandGoldDeep
        case .busy:     return AppColor.waitOrange
        case .packed:   return AppColor.error
        }
    }
}

// MARK: - Header

struct HomeHeaderView: View {
    let park: Park
    let crowdLevel: CrowdLevel
    let lastUpdatedText: String?
    var weather: ParkWeather? = nil
    var hours: ParkHours? = nil

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
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(park.displayName)
                        .font(.largeTitle.bold())
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.82)

                    Text(Self.dateFormatter.string(from: Date()))
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(alignment: .trailing, spacing: AppSpacing.xs) {
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

                    if let lastUpdatedText {
                        Text(lastUpdatedText)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(AppColor.textTertiary)
                            .monospacedDigit()
                    }
                }
            }

            Text("\(greeting). Ready for \(park.displayName)?")
                .font(.title3.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)

            // Park hours — compact open/close status line
            if let hours {
                ParkHoursLine(hours: hours)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Weather context
            if let weather {
                WeatherContextLine(weather: weather)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(AppMotion.standard, value: weather)
        .animation(AppMotion.standard, value: hours)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Park Hours Line (header)

/// Compact dot + status text that sits below the greeting.
/// Color shifts to amber when closing soon so urgency is immediately visible.
private struct ParkHoursLine: View {
    let hours: ParkHours

    private var dotColor: Color {
        if hours.isClosingSoon { return AppColor.warning }
        return hours.isOpen ? AppColor.success : AppColor.textTertiary
    }

    private var textColor: Color {
        if hours.isClosingSoon { return AppColor.warning }
        return hours.isOpen ? AppColor.textSecondary : AppColor.textTertiary
    }

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Circle()
                .fill(dotColor)
                .frame(width: 7, height: 7)

            Text(hours.statusText)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(textColor)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .animation(AppMotion.standard, value: hours.isClosingSoon)
        .accessibilityLabel("Park hours: \(hours.statusText)")
    }
}

// MARK: - Weather Context Line (header)

/// Compact one-line weather summary that lives below the greeting.
/// Feels like ambient context, not a feature.
private struct WeatherContextLine: View {
    let weather: ParkWeather

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: weather.condition.systemImage)
                .symbolRenderingMode(.multicolor)
                .font(.footnote.weight(.semibold))

            Text(weather.headerDisplay)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColor.textSecondary)

            Spacer(minLength: 0)
        }
        .accessibilityLabel("Weather: \(weather.headerDisplay)")
    }
}

// MARK: - Section Header

struct HomeSectionHeader: View {
    let title: String
    var subtitle: String? = nil
    var actionLabel: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack(alignment: .lastTextBaseline, spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(AppColor.textPrimary)
                if let subtitle {
                    Text(subtitle)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            Spacer()

            if let actionLabel, let action {
                Button(action: action) {
                    HStack(spacing: AppSpacing.xs) {
                        Text(actionLabel)
                        Image(systemName: "chevron.right")
                            .font(.caption.weight(.bold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(AppColor.brandPrimary)
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Best Next Ride

struct HomeBestNextRideCard: View {
    let ride: Ride
    let state: LiveRideState
    let park: Park
    let isPlanned: Bool
    var weather: ParkWeather? = nil
    var hours: ParkHours? = nil
    /// Straight-line distance from the user's current location to this ride, in metres.
    /// Nil when GPS is unavailable or the ride has no map coordinate.
    var distanceMeters: CLLocationDistance? = nil
    /// When true, the first-ride onboarding nudge bar is rendered inside this card.
    /// Defaults to false — existing call sites compile without change.
    var showFirstRideNudge: Bool = false
    /// Called when the user taps the dismiss (×) control on the nudge bar,
    /// or taps the nudge text to open ride details. HomeView sets the
    /// @AppStorage flag inside this closure.
    var onNudgeDismiss: () -> Void = {}
    let onShowOnMap: () -> Void
    let onAddToMyDay: () -> Void

    @State private var showDetail = false

    private var trendLabel: String? {
        guard state.status.isRideable,
              state.trend != .unknown,
              state.trend != .stable else {
            return nil
        }
        return state.trend == .rising ? "Rising" : "Dropping"
    }

    // MARK: - "Why this ride?" reasoning

    /// Short weather token for inline use. Uses `weatherHint` verbatim when ≤ 25 chars;
    /// otherwise derives a compact phrase from the signal so the reasoning line stays tidy.
    private var weatherToken: String? {
        guard let weather, weather.signal != .none else { return nil }
        if let hint = weather.weatherHint, hint.count <= 25 { return hint }
        switch weather.signal {
        case .none:     return nil
        case .rainSoon: return "Rain soon"
        case .raining:  return "It's raining"
        case .hotDay:   return "Heat outside"
        }
    }

    /// Up to 3 reason tokens assembled in priority order:
    ///   1. weather  2. closing soon  3. nearby  4. indoors  5. short wait
    private var reasoningTokens: [String] {
        var tokens: [String] = []

        // 1. Weather signal
        if let token = weatherToken { tokens.append(token) }

        // 2. Closing soon
        if let hours, hours.isClosingSoon { tokens.append("Closes soon") }

        // 3. Nearby (< 400 m)
        if let meters = distanceMeters, meters < 400 { tokens.append("Nearby") }

        // 4. Indoor ride
        if !RideEnvironmentTable.isOutdoor(ride) { tokens.append("Indoors") }

        // 5. Short wait (≤ 15 min)
        if let wait = state.waitMinutes, wait <= 15 { tokens.append("Short wait") }

        return Array(tokens.prefix(3))
    }

    /// Joined reasoning line, or nil when fewer than 2 signals are active.
    /// Fewer than 2 signals means there's nothing contextually interesting to surface.
    private var reasoningLine: String? {
        let tokens = reasoningTokens
        guard tokens.count >= 2 else { return nil }
        return tokens.joined(separator: " · ")
    }

    /// True when the weather token is present in the reasoning line. When true, the
    /// separate WeatherHintBar is suppressed — the inline line is the primary signal.
    private var weatherPromotedInline: Bool {
        weatherToken != nil && reasoningLine != nil
    }

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.lg) {
            HStack(alignment: .top, spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Label("Best Next Ride", systemImage: "sparkles")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(park.accentColor)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(park.accentColor.opacity(0.11))
                        .clipShape(Capsule())

                    Text(ride.name)
                        .font(.system(.title2, design: .rounded).weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: AppSpacing.sm)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(state.waitDisplay)
                        .font(.title.bold())
                        .foregroundStyle(state.waitColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text("wait")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textTertiary)
                }
            }

            HStack(spacing: AppSpacing.sm) {
                HomeMetadataPill(
                    icon: "mappin.circle.fill",
                    text: ride.land.isEmpty ? park.displayName : ride.land,
                    color: park.accentColor
                )

                if let trendLabel {
                    HomeMetadataPill(
                        icon: state.trend.systemImage,
                        text: trendLabel,
                        color: state.trend == .rising ? AppColor.error : AppColor.success
                    )
                }

                if state.lightningLaneAvailable {
                    HomeMetadataPill(
                        icon: "bolt.fill",
                        text: "Lightning Lane",
                        color: AppColor.brandGoldDeep
                    )
                }

                if let meters = distanceMeters {
                    HomeMetadataPill(
                        icon: meters < 150 ? "location.fill" : "figure.walk",
                        text: Self.distanceText(meters),
                        color: .blue
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                }
            }

            // Reasoning line — "Why this ride?" context tokens
            if let line = reasoningLine {
                Text(line)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
                    .transition(.opacity)
            }

            // Weather hint — only shown when signal is actionable and not already promoted inline
            if let weather, let hint = weather.weatherHint, let icon = weather.hintIcon,
               !weatherPromotedInline {
                WeatherHintBar(hint: hint, icon: icon, color: weather.hintColor)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // Closing-soon hint — shown within 2 hours of park close
            if let hours, hours.isClosingSoon {
                ClosingSoonHintBar(hint: hours.closingSoonHint)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // ── First-ride onboarding nudge ────────────────────────────────────
            // Shown once, 60 s after the user first opens Home, when they have
            // zero ride logs and have not dismissed it before.
            // Tapping the bar opens ride details (the natural logging entry point).
            // Tapping × dismisses permanently via the onNudgeDismiss closure.
            if showFirstRideNudge {
                FirstRideNudgeBar(
                    onTap: {
                        showDetail = true
                        onNudgeDismiss()
                    },
                    onDismiss: onNudgeDismiss
                )
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            HStack(spacing: AppSpacing.sm) {
                Button {
                    AppHaptic.light()
                    onShowOnMap()
                } label: {
                    Label("View on Map", systemImage: "map.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .foregroundStyle(.white)
                        .background(park.accentColor)
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)

                Button {
                    AppHaptic.light()
                    onAddToMyDay()
                } label: {
                    Label(isPlanned ? "Planned" : "Add to My Day",
                          systemImage: isPlanned ? "checkmark.circle.fill" : "plus.circle.fill")
                        .font(.subheadline.weight(.bold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppSpacing.md)
                        .foregroundStyle(isPlanned ? AppColor.success : park.accentColor)
                        .background((isPlanned ? AppColor.success : park.accentColor).opacity(0.11))
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.md))
                }
                .buttonStyle(.plain)
            }

            Button {
                showDetail = true
            } label: {
                HStack {
                    Text("Ride details")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppColor.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.xl)
        .background(
            LinearGradient(
                colors: [park.accentBackground, AppColor.card],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xxl)
                .strokeBorder(park.accentColor.opacity(0.16), lineWidth: 1)
        )
        .shadow(color: park.accentColor.opacity(0.14), radius: 18, x: 0, y: 8)
        .animation(AppMotion.standard, value: weather)
        .animation(AppMotion.standard, value: hours?.isClosingSoon)
        .animation(AppMotion.standard, value: distanceMeters)
        .animation(AppMotion.standard, value: reasoningLine)
        .animation(AppMotion.standard, value: showFirstRideNudge)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: - Distance text helper

    /// Human-readable distance string for the metadata pill.
    ///   < 150 m  → "Nearby"
    ///   150–999 m → "340 m"
    ///   ≥ 1 km   → "1.2 km"
    private static func distanceText(_ meters: CLLocationDistance) -> String {
        if meters < 150 { return "Nearby" }
        if meters < 1000 { return "\(Int(meters.rounded())) m" }
        return String(format: "%.1f km", meters / 1000)
    }
}

// MARK: - First-Ride Nudge Bar

/// Inline hint shown inside the Best Next Ride card once the user has been in
/// the app for 60+ seconds with zero ride logs. Tapping opens ride details;
/// tapping × permanently dismisses via HomeView's @AppStorage flag.
///
/// Visual language: frosted-glass pill — present but not dominant.
private struct FirstRideNudgeBar: View {
    let onTap:    () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            // ── Tap target — opens ride details and dismisses ──────────────────
            Button(action: { AppHaptic.light(); onTap() }) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "hand.tap.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(Color.accentColor)
                        .frame(width: 18)

                    Text("Tap to log your first ride and help Smart mode learn what you like.")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // ── Dismiss control ────────────────────────────────────────────────
            Button(action: { AppHaptic.light(); onDismiss() }) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(AppColor.textTertiary.opacity(0.12), in: Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss")
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: AppRadius.sm, style: .continuous))
        .accessibilityLabel("First ride tip: Tap to log your first ride and help Smart mode learn what you like.")
    }
}

// MARK: - Ride Streak Banner

/// Compact micro-reward banner shown directly below the Best Next Ride card
/// when the user logs ride milestone counts (3, 5, 10) during a single park day.
///
/// Behavior:
///   • Auto-dismisses after 4 seconds (timer managed by HomeView).
///   • Tapping anywhere on the banner dismisses immediately via onTap.
///   • No close button — the whole surface is the dismiss target,
///     keeping the UI as minimal as possible.
///
/// Visual language: white card with a hairline success-green border — positive
/// but not alarming. Sits flush in the card stack, not floating above it.
struct RideStreakBanner: View {
    let message: String
    let onTap:   () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.sm) {
                Text(message)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: AppSpacing.sm)

                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(AppColor.textTertiary)
                    .frame(width: 20, height: 20)
                    .background(AppColor.textTertiary.opacity(0.10), in: Circle())
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                    .strokeBorder(AppColor.success.opacity(0.30), lineWidth: 1)
            )
            .shadow(color: AppColor.success.opacity(0.08), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(message)
        .accessibilityHint("Double tap to dismiss")
    }
}

// MARK: - Weather Hint Bar (Best Next Ride card)

/// One-line weather hint rendered inside the Best Next Ride card.
/// Only mounted when WeatherSignal is non-.none so it never shows filler.
private struct WeatherHintBar: View {
    let hint: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .symbolRenderingMode(.monochrome)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)

            Text(hint)
                .font(.caption.weight(.medium))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(color.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .accessibilityLabel("Weather tip: \(hint)")
    }
}

// MARK: - Closing-Soon Hint Bar (Best Next Ride card)

/// One-line urgency hint rendered inside the Best Next Ride card when the park
/// closes within the next 2 hours. Message is calibrated to time remaining.
private struct ClosingSoonHintBar: View {
    let hint: String

    var body: some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: "clock.badge.exclamationmark.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.warning)

            Text(hint)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.warning)
                .lineLimit(1)
                .minimumScaleFactor(0.85)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppSpacing.md)
        .padding(.vertical, AppSpacing.sm)
        .background(AppColor.warning.opacity(0.09))
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.sm))
        .accessibilityLabel(hint)
    }
}

struct HomeBestNextRideEmptyCard: View {
    let park: Park
    let hasRides: Bool
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Label("Best Next Ride", systemImage: "sparkles")
                .font(.caption.weight(.bold))
                .foregroundStyle(park.accentColor)

            Text(hasRides ? "Checking the best move." : "Loading attractions.")
                .font(.title2.bold())
                .foregroundStyle(AppColor.textPrimary)

            Text(hasRides ? "Live wait times are still warming up. You can browse all attractions now." : "Park data will appear here in a moment.")
                .font(.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            Button(action: action) {
                Label("Browse Attractions", systemImage: "list.bullet")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(park.accentColor)
                    .padding(.horizontal, AppSpacing.md)
                    .padding(.vertical, AppSpacing.sm)
                    .background(park.accentColor.opacity(0.11))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xxl))
        .shadow(color: .black.opacity(0.06), radius: 12, x: 0, y: 5)
    }
}

private struct HomeMetadataPill: View {
    let icon: String
    let text: String
    let color: Color

    var body: some View {
        HStack(spacing: AppSpacing.xs) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text(text)
                .font(.caption.weight(.semibold))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, AppSpacing.sm)
        .padding(.vertical, AppSpacing.xs)
        .background(color.opacity(0.10))
        .clipShape(Capsule())
    }
}

// MARK: - Quick Filters

struct HomeQuickFilterRow: View {
    let shortWaitCount: Int
    let openNowCount: Int
    let plannedCount: Int
    let totalRideCount: Int
    let onShortWaits: () -> Void
    let onNearby: () -> Void
    let onOpenNow: () -> Void
    let onMyPlan: () -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                HomeFilterChip(
                    title: "Short Waits",
                    value: "\(shortWaitCount)",
                    icon: "timer",
                    color: AppColor.success,
                    action: onShortWaits
                )
                HomeFilterChip(
                    title: "Nearby",
                    value: "Map",
                    icon: "location.fill",
                    color: Color.blue,
                    action: onNearby
                )
                HomeFilterChip(
                    title: "Open Now",
                    value: "\(openNowCount)/\(totalRideCount)",
                    icon: "checkmark.circle.fill",
                    color: AppColor.brandPrimary,
                    action: onOpenNow
                )
                HomeFilterChip(
                    title: "My Plan",
                    value: "\(plannedCount)",
                    icon: "checklist",
                    color: Color.purple,
                    action: onMyPlan
                )
            }
        }
    }
}

private struct HomeFilterChip: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: { AppHaptic.light(); action() }) {
            HStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.caption.weight(.bold))
                    .frame(width: 24, height: 24)
                    .foregroundStyle(color)
                    .background(color.opacity(0.11), in: Circle())

                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                    Text(value)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .monospacedDigit()
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Up Next

struct HomeUpNextPreviewCard: View {
    let rides: [(ride: Ride, state: LiveRideState?)]
    let park: Park
    let onShowOnMap: (Ride) -> Void
    let onAddToMyDay: (Ride) -> Void

    var body: some View {
        VStack(spacing: 0) {
            if rides.isEmpty {
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("No attractions yet")
                        .font(.headline)
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Pull to refresh or check the map for live updates.")
                        .font(.subheadline)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(AppSpacing.cardPadding)
            } else {
                ForEach(Array(rides.enumerated()), id: \.element.ride.id) { index, element in
                    HomeRidePreviewRow(
                        ride: element.ride,
                        state: element.state,
                        park: park,
                        onShowOnMap: { onShowOnMap(element.ride) },
                        onAddToMyDay: { onAddToMyDay(element.ride) }
                    )

                    if index < rides.count - 1 {
                        Divider()
                            .padding(.leading, 88)
                    }
                }
            }
        }
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

private struct HomeRidePreviewRow: View {
    let ride: Ride
    let state: LiveRideState?
    let park: Park
    let onShowOnMap: () -> Void
    let onAddToMyDay: () -> Void

    @State private var showDetail = false

    /// Attraction type resolved from static master data — O(1), no allocation.
    private var attractionType: AttractionType {
        RideMasterData.typeByStableID[ride.id] ?? .ride
    }

    private var waitText: String {
        if let live = state {
            // Live state available: use the standard display string.
            // For shows/meets with no posted wait (waitMinutes == nil), fall
            // back to type-aware text rather than a status label.
            if live.status.isRideable, live.waitMinutes == nil {
                switch attractionType {
                case .characterMeet: return "Times vary"
                case .show:          return "Schedule"
                default:             return live.waitDisplay
                }
            }
            return live.waitDisplay
        }
        // No live state — type-aware placeholder.
        switch attractionType {
        case .characterMeet: return "Times vary"
        case .show:          return "Schedule"
        default:             return "—"
        }
    }

    private var waitColor: Color {
        state?.waitColor ?? AppColor.textTertiary
    }

    private var statusText: String {
        guard let state else { return "No live wait yet" }
        if state.status.isRideable {
            if let mins = state.waitMinutes {
                return AppColor.waitLabel(minutes: mins)
            }
            return "Open"
        }
        return state.status.displayLabel
    }

    var body: some View {
        Button {
            showDetail = true
            AppHaptic.light()
        } label: {
            HStack(spacing: AppSpacing.md) {
                VStack(spacing: 2) {
                    Text(waitText)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(waitColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                    Text("wait")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(AppColor.textTertiary)
                }
                .frame(width: 64)

                VStack(alignment: .leading, spacing: 3) {
                    Text(ride.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: AppSpacing.xs) {
                        Text(ride.land)
                            .lineLimit(1)
                        Text("·")
                        Text(statusText)
                            .foregroundStyle(waitColor)
                    }
                    .font(.caption)
                    .foregroundStyle(AppColor.textTertiary)
                }

                Spacer(minLength: AppSpacing.sm)

                Menu {
                    Button {
                        onShowOnMap()
                    } label: {
                        Label("View on Map", systemImage: "map.fill")
                    }

                    Button {
                        onAddToMyDay()
                    } label: {
                        Label("Add to My Day", systemImage: "plus.circle.fill")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle.fill")
                        .font(.title3)
                        .foregroundStyle(park.accentColor)
                        .frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, AppSpacing.cardPadding)
            .padding(.vertical, AppSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            RideDetailView(ride: ride)
        }
    }
}

// MARK: - My Day

struct HomeMyDayPreviewCard: View {
    let previewItems: [MyDayItem]
    let remainingCount: Int
    let completedCount: Int
    let onTapItem: (MyDayItem) -> Void
    let onTapSeeAll: () -> Void
    let onAddItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: AppSpacing.md) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(remainingCount) remaining")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("\(completedCount) completed")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(AppColor.textSecondary)
                }

                Spacer()

                Button(action: { AppHaptic.light(); onAddItem() }) {
                    Label("Add", systemImage: "plus")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(AppColor.brandPrimary)
                        .padding(.horizontal, AppSpacing.md)
                        .padding(.vertical, AppSpacing.xs)
                        .background(AppColor.brandPrimary.opacity(0.10))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.cardPadding)

            if previewItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text("No plan yet")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(AppColor.textPrimary)
                    Text("Add rides, meals, shows, or reminders for the day.")
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                .padding(.horizontal, AppSpacing.cardPadding)
                .padding(.bottom, AppSpacing.cardPadding)
            } else {
                ForEach(Array(previewItems.enumerated()), id: \.element.id) { index, item in
                    Divider()
                    HomeMyDayPreviewRow(item: item) {
                        onTapItem(item)
                    }
                    .opacity(index > 3 ? 0.75 : 1)
                }
            }

            Divider()

            Button {
                AppHaptic.light()
                onTapSeeAll()
            } label: {
                HStack {
                    Text("Open My Day")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(AppColor.brandPrimary)
                .padding(AppSpacing.cardPadding)
            }
            .buttonStyle(.plain)
        }
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
    }
}

private struct HomeMyDayPreviewRow: View {
    let item: MyDayItem
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: AppSpacing.md) {
                ZStack {
                    Circle()
                        .fill(item.type.color.opacity(item.isChecked ? 0.07 : 0.12))
                        .frame(width: 34, height: 34)
                    Image(systemName: item.type.systemImage)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(item.isChecked ? item.type.color.opacity(0.45) : item.type.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .font(.subheadline.weight(item.isChecked ? .regular : .semibold))
                        .foregroundStyle(item.isChecked ? AppColor.textTertiary : AppColor.textPrimary)
                        .lineLimit(1)
                        .strikethrough(item.isChecked, color: AppColor.textTertiary)

                    if let land = item.land {
                        Text(land)
                            .font(.caption)
                            .foregroundStyle(AppColor.textTertiary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                if item.isChecked {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(AppColor.success)
                } else if let time = item.formattedTime {
                    Text(time)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(AppColor.textSecondary)
                        .monospacedDigit()
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.bold))
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

// MARK: - Park Day Summary Card

/// "Your Day So Far" summary shown near the bottom of the Home scroll view
/// once the user has logged ≥3 rides today. Dismissed per calendar day —
/// the parent supplies a UserDefaults-backed dismissal flag and closure.
///
/// Displays:
///   • Total rides logged today (large numeral)
///   • First ride of the day (if available)
///   • Most recent ride logged (if available, and distinct context from first)
///
/// Visual language: clean white card with a subtle gold border — celebratory
/// but understated. No action buttons; this is ambient progress feedback.
struct HomeParkDaySummaryCard: View {
    let rideCount: Int
    let firstRideName: String?
    let mostRecentRideName: String?
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            // ── Header ────────────────────────────────────────────────────────
            HStack(alignment: .center, spacing: AppSpacing.sm) {
                Label("Your Day So Far", systemImage: "sun.max.fill")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(AppColor.brandGoldDeep)
                    .symbolRenderingMode(.monochrome)

                Spacer(minLength: AppSpacing.sm)

                Button(action: { AppHaptic.light(); onDismiss() }) {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(AppColor.textTertiary)
                        .frame(width: 22, height: 22)
                        .background(AppColor.textTertiary.opacity(0.10), in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Dismiss")
            }

            // ── Ride count ────────────────────────────────────────────────────
            HStack(alignment: .firstTextBaseline, spacing: AppSpacing.xs) {
                Text("\(rideCount)")
                    .font(.system(.title, design: .rounded).weight(.bold))
                    .foregroundStyle(AppColor.textPrimary)
                    .monospacedDigit()
                Text(rideCount == 1 ? "ride logged today" : "rides logged today")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(AppColor.textSecondary)
            }

            // ── Stat rows ─────────────────────────────────────────────────────
            if let first = firstRideName {
                ParkDayStatRow(label: "First ride", value: first)
            }
            // Show "Most recent" when there are multiple logs so the two rows
            // always refer to different rides. (Card only appears at ≥3 rides,
            // so first and most-recent will always be distinct.)
            if let recent = mostRecentRideName {
                ParkDayStatRow(label: "Most recent", value: recent)
            }
        }
        .padding(AppSpacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(AppColor.card)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppRadius.xl, style: .continuous)
                .strokeBorder(AppColor.brandGoldDeep.opacity(0.20), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.05), radius: 10, x: 0, y: 4)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Your day so far: \(rideCount) rides logged today.")
    }
}

private struct ParkDayStatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Text(label)
                .font(.caption.weight(.medium))
                .foregroundStyle(AppColor.textTertiary)
                .frame(width: 82, alignment: .leading)

            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 0)
        }
    }
}

// MARK: - Quick Actions

struct HomeQuickActionsRow: View {
    let park: Park
    let onMap: () -> Void
    let onMyDay: () -> Void
    let onAttractions: () -> Void
    let onAddItem: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.md) {
            Text("Quick Actions")
                .font(.title3.bold())
                .foregroundStyle(AppColor.textPrimary)

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppSpacing.sm),
                    GridItem(.flexible(), spacing: AppSpacing.sm)
                ],
                spacing: AppSpacing.sm
            ) {
                HomeQuickActionButton(
                    icon: "map.fill",
                    title: "Map",
                    subtitle: "Live location",
                    color: park.accentColor,
                    action: onMap
                )
                HomeQuickActionButton(
                    icon: "checklist",
                    title: "My Day",
                    subtitle: "Plan & check off",
                    color: Color.purple,
                    action: onMyDay
                )
                HomeQuickActionButton(
                    icon: "list.bullet",
                    title: "Attractions",
                    subtitle: "Browse all",
                    color: Color.blue,
                    action: onAttractions
                )
                HomeQuickActionButton(
                    icon: "plus.circle.fill",
                    title: "Add Item",
                    subtitle: "Build your plan",
                    color: AppColor.success,
                    action: onAddItem
                )
            }
        }
    }
}

private struct HomeQuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button {
            AppHaptic.light()
            action()
        } label: {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(color)
                    .frame(width: 38, height: 38)
                    .background(color.opacity(0.12), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(AppColor.textPrimary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColor.card)
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.lg))
            .shadow(color: .black.opacity(0.04), radius: 8, x: 0, y: 3)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.97 : 1)
        .animation(AppMotion.quick, value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
