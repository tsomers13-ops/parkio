// swift-tools-version: 5.9
//
//  Package.swift — Parkio developer tooling.
//
//  This manifest exists ONLY to build content-export tools that run on macOS.
//  It is not part of the iOS app build: Xcode builds Parkio.xcodeproj, which
//  compiles the `Parkio/` folder via a PBXFileSystemSynchronizedRootGroup and
//  is entirely unaware of this file.
//
//  The exporter reuses the app's real Swift models by listing them explicitly
//  in `sources` — there is no parsing of Swift source and no duplicated data.
//  Exporter code lives in `Tools/`, outside the synchronized `Parkio/` folder,
//  so it is never compiled into the shipping app.
//
import PackageDescription

// App sources the exporter must NOT compile. Listed so the manifest stays a
// truthful description of the tool's inputs.
let sourcesNotInExporter: [String] = [
                "AppStoreInfo.plist",
                "PARKIO_ACTIVE_CONTEXT.md",
                "README.md",
                "Parkio/Assets.xcassets",
                "Parkio/Preview Content",
                "Parkio/PrivacyInfo.xcprivacy",
                "Parkio/ParkioApp.swift",
                "Parkio/Features",
                "Parkio/Services",
                "Parkio/Tokens",
                "Parkio/ViewModels",
                "Parkio/Views",
                "Parkio/Models/DTOs",
                "Parkio/Models/AppNavigationCoordinator.swift",
                "Parkio/Models/DiningRating.swift",
                "Parkio/Models/DiningVenueKeys.swift",
                "Parkio/Models/DiningRatingStore.swift",
                "Parkio/Models/DiningRecommendation.swift",
                "Parkio/Models/DiningReview.swift",
                "Parkio/Models/GuestServicePOI.swift",
                "Parkio/Models/MyDayItem.swift",
                "Parkio/Models/Park+Appearance.swift",
                "Parkio/Models/ParkVisit.swift",
                "Parkio/Models/Ride.swift",
                "Parkio/Models/RideLog.swift",
                "Parkio/Models/RideSeeder.swift",
                "Parkio/Models/ShopMasterData.swift",
                "Parkio/Models/WaitTimeCache.swift",
]

let package = Package(
    name: "ParkioTools",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "dining-export",
            path: ".",
            // App sources the exporter must NOT compile. Listed so the
            // manifest stays a truthful description of the tool's inputs.
            exclude: sourcesNotInExporter,
            sources: [
                "Tools/DiningExporter",
                // Real app models — single source of truth for Dining content.
                "Parkio/Models/Park.swift",
                "Parkio/Models/DiningMetadata.swift",
                "Parkio/Models/RideMasterData.swift",
                "Parkio/Models/RideMasterData+Dining.swift",
            ]
        ),

        // The Community Ratings foundation, tested here because the Xcode
        // project has no test target and adding one would mean editing
        // project.pbxproj by hand. These files are deliberately Foundation-only
        // (no SwiftUI, no SwiftData) so they compile and run under `swift test`
        // exactly as they do in the app.
        .testTarget(
            name: "ParkioRatingsTests",
            path: ".",
            // Everything the exporter skips, minus the two things these tests
            // exist to exercise: the Ratings service layer and the generated
            // venueKey mapping.
            exclude: sourcesNotInExporter.filter {
                $0 != "Parkio/Services"
                    && $0 != "Parkio/Models/DiningVenueKeys.swift"
                    && $0 != "Parkio/Views"
            } + ["Tools/DiningExporter"],
            sources: [
                "Tests/ParkioRatingsTests",
                // Real app sources under test — compiled in, not duplicated.
                "Parkio/Services/Ratings",
                "Parkio/Models/DiningVenueKeys.swift",
                // The view model is deliberately SwiftUI-free — Foundation and
                // Observation only — so the whole Community state machine is
                // testable without dragging the view layer into SPM.
                "Parkio/Views/Dining/Community/CommunityRatingViewModel.swift",
                // The real Dining content deliberately is NOT compiled here:
                // SPM forbids two targets sharing sources, and those files
                // belong to the exporter. The 62/24 eligibility boundary is
                // asserted against the real 86 venues by
                // `dining-export --verify-venue-keys`, which already owns them.
            ]
        )
    ]
)
