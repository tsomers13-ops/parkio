// UITestConfiguration.swift — test-only launch hooks, inert in shipping builds.
//
// A UI test needs a deterministic starting point. Driving Home's own controls
// would make the test depend on which park was last selected, whether the
// welcome banner is showing, and what "Best Next Ride" happens to be — none of
// which this test is about.
//
// So a launch argument puts the app on one known surface and nothing more. The
// whole type compiles to `false` outside DEBUG, so a shipping build cannot be
// steered by launch arguments even if someone passes them.

import Foundation

enum UITestConfiguration {

    /// True only in a DEBUG build launched by the UI test bundle.
    static var isRunningUITests: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-parkio-uitests")
        #else
        return false
        #endif
    }

    /// Open EPCOT's dining list on launch — the surface the Community
    /// regression test starts from. EPCOT because its venues are inside the
    /// 62-venue Community pilot; the other parks' dining is deliberately not.
    static var opensEpcotDiningList: Bool {
        isRunningUITests
            && ProcessInfo.processInfo.arguments.contains("-parkio-open-epcot-dining")
    }

    /// Select EPCOT and stay on Home — the surface Best Food Nearby lives on.
    /// Only the park is forced; the recommendations themselves come from
    /// DiningRecommendationService exactly as in production.
    static var selectsEpcotOnHome: Bool {
        isRunningUITests
            && ProcessInfo.processInfo.arguments.contains("-parkio-select-epcot")
    }
}
