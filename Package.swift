// swift-tools-version: 5.9
//
//  Package.swift — Parkio developer tooling.
//
//  This manifest is not part of the iOS app build. Xcode builds
//  Parkio.xcodeproj, which compiles the `Parkio/` folder via a
//  PBXFileSystemSynchronizedRootGroup and is unaware of this file.
//
//  The `Parkio` library is a macOS slice of the app sources that
//  `swift test` and `dining-export` need. Each app file belongs to
//  exactly one SwiftPM target. UIKit and SwiftUI views stay out.
//
import PackageDescription

let package = Package(
    name: "ParkioTools",
    platforms: [.macOS(.v14)],
    targets: [
        .target(
            name: "Parkio",
            path: "Parkio",
            sources: [
                "Services/Ratings",
                "Services/DiningRecommendationService.swift",
                "Models/DiningVenueKeys.swift",
                "Models/Park.swift",
                "Models/DiningMetadata.swift",
                "Models/RideMasterData.swift",
                "Models/RideMasterData+Dining.swift",
                "Models/Ride.swift",
                "Models/RideLog.swift",
                "Models/DiningRating.swift",
                "Models/DiningRecommendation.swift",
                "Models/DiningRatingStore.swift",
                "Views/Dining/Community/CommunityRatingViewModel.swift",
                "Features/Map/MapImageResolution.swift",
                "Features/Map/MapRoutingDecision.swift",
                "Features/Map/MapPinIdentityResolver.swift",
                "Features/Map/Models/ParkMapPin.swift",
                "Features/Map/Models/ParkMapPinData.swift",
            ],
            // App types stay internal. dining-export is an executable, so the
            // library is built for testing and main.swift uses @testable import.
            swiftSettings: [.unsafeFlags(["-enable-testing"])]
        ),

        .executableTarget(
            name: "dining-export",
            dependencies: ["Parkio"],
            path: "Tools/DiningExporter"
        ),

        .testTarget(
            name: "ParkioRatingsTests",
            dependencies: ["Parkio"],
            path: "Tests/ParkioRatingsTests"
        ),

        // Map routing and pin lookup. ParkioAttractionsTests stays in the
        // Xcode test bundle only; it is not a SwiftPM target.
        .testTarget(
            name: "ParkioMapTests",
            dependencies: ["Parkio"],
            path: "Tests/ParkioMapTests"
        ),
    ]
)
