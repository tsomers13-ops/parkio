// WalkingRouteSummaryView.swift — shared routed distance/ETA presentation.
//
// This lives in the shared bottom sheet so Explore and Live map modes present
// the same route state. It never substitutes straight-line distance when
// MapKit routing or the user's location is unavailable.

import SwiftUI
import MapKit

struct WalkingRouteSummaryView: View {
    let coordinate: CLLocationCoordinate2D
    let destinationID: String
    let destinationName: String

    @Environment(WalkingRouteModel.self) private var walkingRouteModel
    @Environment(LocationService.self) private var locationService

    var body: some View {
        Group {
            switch walkingRouteModel.state {
            case .idle:
                EmptyView()

            case .loading:
                summaryRow(icon: "figure.walk", text: "Calculating walking route…") {
                    ProgressView()
                        .controlSize(.small)
                }
                .accessibilityIdentifier("walking-route-loading")

            case let .available(route):
                summaryRow(
                    icon: "figure.walk",
                    text: "\(route.formattedDistance) · ~\(route.estimatedMinutes) min walk"
                )
                .accessibilityIdentifier("walking-route-available")

            case let .unavailable(reason):
                unavailableRow(reason: reason)
                    .accessibilityIdentifier("walking-route-unavailable")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Color.accentColor.opacity(0.08),
            in: RoundedRectangle(cornerRadius: AppRadius.md, style: .continuous)
        )
    }

    private func summaryRow<Trailing: View>(
        icon: String,
        text: String,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 22)
            Text(text)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(AppColor.textPrimary)
            Spacer(minLength: 0)
            trailing()
        }
    }

    private func summaryRow(icon: String, text: String) -> some View {
        summaryRow(icon: icon, text: text) { EmptyView() }
    }

    private func unavailableRow(reason: WalkingRouteUnavailableReason) -> some View {
        HStack(alignment: .center, spacing: AppSpacing.sm) {
            Image(systemName: reason == .locationDenied ? "location.slash" : "figure.walk")
                .foregroundStyle(AppColor.textSecondary)
                .frame(width: 22)

            Text(reason.message)
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: AppSpacing.xs)

            fallbackButton(for: reason)
        }
    }

    @ViewBuilder
    private func fallbackButton(for reason: WalkingRouteUnavailableReason) -> some View {
        switch reason {
        case .permissionRequired:
            Button("Enable") {
                locationService.requestWhenInUse()
            }
            .buttonStyle(.borderless)

        case .locationDenied:
            Button("Settings") {
                guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                UIApplication.shared.open(url)
            }
            .buttonStyle(.borderless)

        case .network, .throttled, .server, .unknown:
            HStack(spacing: AppSpacing.sm) {
                Button("Retry") {
                    walkingRouteModel.retry()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("walking-route-retry")

                Button("Maps") {
                    openMaps()
                }
                .buttonStyle(.borderless)
                .accessibilityIdentifier("walking-route-open-maps")
            }

        case .locationUnavailable, .noRoute:
            Button("Open Maps") {
                openMaps()
            }
            .buttonStyle(.borderless)
            .accessibilityIdentifier("walking-route-open-maps")
        }
    }

    private func openMaps() {
        WalkingDirectionsLauncher.open(
            destinationID: destinationID,
            coordinate: coordinate,
            destinationName: destinationName
        )
    }
}

@MainActor
enum WalkingDirectionsLauncher {
    static func resolvedCoordinate(
        destinationID: String,
        coordinate: CLLocationCoordinate2D
    ) -> CLLocationCoordinate2D {
        WalkingRouteEndpointResolver.coordinate(for: destinationID, fallback: coordinate)
    }

    static func open(
        destinationID: String,
        coordinate: CLLocationCoordinate2D,
        destinationName: String
    ) {
        let destination = resolvedCoordinate(
            destinationID: destinationID,
            coordinate: coordinate
        )
        let placemark = MKPlacemark(coordinate: destination)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = destinationName
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }
}
