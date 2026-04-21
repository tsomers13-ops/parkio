// LocationButton.swift — Map location / follow-mode button.
//
// Auth states (when NOT authorized):
//   .notDetermined  — grey arrow outline + "?" badge.
//                     Tap → requestWhenInUse() then starts location updates.
//   .denied /       — grey arrow outline + slash badge.
//   .restricted       Tap → opens app Settings (user must re-enable manually).
//
// Follow-mode states (when authorized):
//   .none           — outline arrow, textPrimary colour.
//                     Tap → cycleFollowMode() → enters .follow
//   .follow         — filled arrow, accentColor.
//                     Tap → cycleFollowMode() → enters .followHeading
//   .followHeading  — compass/heading arrow, accentColor.
//                     Tap → cycleFollowMode() → exits to .none
//
// Visual system image mapping:
//   .none           → "location"
//   .follow         → "location.fill"
//   .followHeading  → "location.north.line.fill"
//
// Placement:
//   Bottom-trailing corner of RealMapScreen, above the safe area inset.

import SwiftUI
import CoreLocation

// MARK: - LocationButton

struct LocationButton: View {

    // ── Dependencies ──────────────────────────────────────────────────────────

    @Environment(LocationService.self) private var locationService
    @Environment(MapViewModel.self)    private var mapVM

    // MARK: - Body

    var body: some View {
        Button(action: handleTap) {
            buttonImage
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(foregroundColor)
                .padding(10)
                .background(.regularMaterial, in: Circle())
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        // Animate on auth status changes and follow mode changes.
        .animation(AppMotion.standard, value: locationService.authorizationStatus.rawValue)
        .animation(AppMotion.standard, value: mapVM.followMode)
    }

    // MARK: - Icon

    private var buttonImage: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: arrowSystemImage)

            // Badge overlaid top-right when location is not authorized.
            if let badge = badgeSystemImage {
                Image(systemName: badge)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(badgeColor)
                    .padding(1)
                    .background(Color(.systemBackground), in: Circle())
                    .offset(x: 4, y: -4)
            }
        }
    }

    // MARK: - Derived appearance

    private var arrowSystemImage: String {
        guard locationService.isAuthorized else { return "location" }
        switch mapVM.followMode {
        case .none:           return "location"
        case .follow:         return "location.fill"
        case .followHeading:  return "location.north.line.fill"
        }
    }

    private var foregroundColor: Color {
        guard locationService.isAuthorized else { return AppColor.textTertiary }
        switch mapVM.followMode {
        case .none:           return AppColor.textPrimary
        case .follow,
             .followHeading:  return Color.accentColor
        }
    }

    private var badgeSystemImage: String? {
        switch locationService.authorizationStatus {
        case .notDetermined:                  return "questionmark"
        case .denied, .restricted:            return "slash.circle.fill"
        default:                              return nil
        }
    }

    private var badgeColor: Color {
        switch locationService.authorizationStatus {
        case .denied, .restricted:            return AppColor.error
        default:                              return AppColor.textTertiary
        }
    }

    // MARK: - Tap action

    private func handleTap() {
        AppHaptic.light()

        switch locationService.authorizationStatus {
        case .notDetermined:
            // Prompt the system authorization dialog. Location updates begin
            // once the user grants permission (handled in LocationService delegate).
            locationService.requestWhenInUse()

        case .authorizedWhenInUse, .authorizedAlways:
            // Cycle through follow modes: none → follow → followHeading → none.
            // LocationService must be running so the camera can track position.
            locationService.startUpdating()
            mapVM.cycleFollowMode()

        case .denied, .restricted:
            // Only Settings can recover a denied state.
            if let url = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url)
            }

        @unknown default:
            locationService.requestWhenInUse()
        }
    }
}

// MARK: - Preview

#if DEBUG
import SwiftData

#Preview("Follow modes") {
    let schema    = Schema([Ride.self, RideLog.self, WaitTimeCache.self])
    let container = try! ModelContainer(
        for: schema,
        configurations: ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
    )
    let waitVM = WaitTimeViewModel(container: container)
    let mapVM  = MapViewModel(parkId: "magic-kingdom", waitTimeVM: waitVM)
    let locSvc = LocationService()

    return VStack(spacing: 24) {
        // Simulate each follow state visually.
        Text("none").font(.caption.weight(.semibold))
        LocationButton()
            .environment(mapVM)
            .environment(locSvc)

        Text("follow (tap once)").font(.caption.weight(.semibold))
        Text("followHeading (tap twice)").font(.caption.weight(.semibold))
    }
    .padding(32)
    .background(AppColor.background)
}
#endif
