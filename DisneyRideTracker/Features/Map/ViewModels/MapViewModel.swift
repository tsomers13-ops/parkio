// MapViewModel.swift — All state and logic for the Maps feature.
//
// Responsibilities:
//   • Own the MapKit camera position.
//   • Load annotations from MapCoordinateService.
//   • Merge annotations with live wait data from WaitTimeViewModel.
//   • Manage ride selection, bottom sheet detent, and filter state.
//   • Phase 2: follow mode, heading, bearing line.
//   • Phase 3: ride proximity, marker decluttering.
//   • Phase 4: nearby rides, dominant land, best-next-ride recommendation.
//   • Phase 5: staged annotation pipeline with debug snapshot support.
//   • Phase 6: P1 label-collision — p1LabelSafeIds(among:latDelta:viewportWidth:)
//
// ── Annotation pipeline (buildVisibleAnnotations) ────────────────────────────
//
//   Stage 1: Park-scoped MapRideAnnotation → RideAnnotation (defensive parkId filter
//            + priority assignment). Under normal operation this matches `annotations`
//            exactly; the filter catches stale state during rapid park switches.
//   Stage 2: Coordinate validation — strip (0,0) and out-of-range positions
//   Stage 3: Zoom-gate — hide lower-priority rides at very wide zoom levels
//   Stage 4: Filter state — apply showRidden / hideClosed / planOnly / onlyLowWait
//   Stage 5: Declutter — density-based suppression in tight clusters
//
// ── Park-scope contract ───────────────────────────────────────────────────────
//
//   Every property that feeds the map, the HUD, or the annotation pipeline
//   must be scoped to self.parkId — NOT to waitTimeVM.activeParkId.
//
//   Both parkId and activeParkId respond to the same selectedPark binding change
//   via separate .onChange handlers; their update order is undefined. The helper
//   property `parkScopedLiveRides` insulates all downstream computation from that
//   race by always filtering waitTimeVM.liveRides to self.parkId.
//
// ── MapFilterState ────────────────────────────────────────────────────────────
//
//   showRidden  (default true)  — hide ridden rides when false
//   hideClosed  (default false) — hide non-rideable rides when true
//   planOnly    (default false) — show only My Day rides when true
//   onlyLowWait (default false) — hide rides ≥ 30 min when true
//
// ── planOnly wiring ───────────────────────────────────────────────────────────
//
//   updatePlannedRideIds(_:) must be called whenever MyDayStore.items changes.
//   This is wired in RealMapScreen via .onChange(of: myDayStore.items).
//
// ── Declutter tuning ─────────────────────────────────────────────────────────
//
//   Four interlocking mechanisms prevent over-suppression at default park zoom:
//
//   1. Zoom-proportional geographic gate  (geographicDeclutterGate)
//      gate = latDelta × 0.065, clamped [0.0003°, 0.0020°]
//      At MK default (0.013): gate ≈ 0.00085° ≈ 95 m
//      Wider gate at wide zoom, tighter as user zooms in.
//
//   2. Lenient adaptive cluster limits  (adaptiveClusterLimit)
//      latDelta < 0.008  → nil (no suppression — satisfies P3 full visibility at < 0.006)
//      latDelta < 0.012  → 10  (effectively unlimited for any real Disney land)
//      latDelta ≤ 0.020  → 8   (default park zoom — very lenient)
//      latDelta > 0.020  → 5   (wide zoom — light control)
//
//   3. P2 protection rule  (p2CanBeSuppressed)
//      A P2 ride may only enter the suppression path when 5+ other P2 rides
//      are already in `kept` within 0.0005° (≈ 55 m) on each axis.
//      In practice no single Disney land has that many P2 rides that close,
//      so P2 rides are never suppressed at normal park zoom.
//
//   4. 85% visibility floor  (applyVisibilityFloor)
//      Active at latDelta > 0.010. After the candidate loop, if more than 15%
//      of the input set was suppressed, the highest-priority suppressed rides
//      are restored until the floor is met.

import SwiftUI
import MapKit
import Observation
import SwiftData

typealias MapSheetDetent = SheetDetent

// MARK: - Follow mode

enum FollowMode: Equatable {
    case none
    case follow
    case followHeading
}

// MARK: - Ride proximity

enum RideProximity: Equatable {
    case nearby     // < 150 m
    case moderate   // 150–400 m
    case far        // > 400 m

    init(distance: CLLocationDistance) {
        switch distance {
        case ..<150:  self = .nearby
        case ..<400:  self = .moderate
        default:      self = .far
        }
    }

    var polylineColor: Color {
        switch self {
        case .nearby:   return Color.green.opacity(0.5)
        case .moderate: return Color.accentColor.opacity(0.45)
        case .far:      return Color.secondary.opacity(0.4)
        }
    }

    var walkIcon: String {
        switch self {
        case .nearby, .moderate: return "figure.walk"
        case .far:               return "figure.walk.motion"
        }
    }
}

// MARK: - Nearby ride (for NearbyRideTray)

struct NearbyRide: Identifiable {
    let annotation: RideAnnotation
    let enriched:   EnrichedMarker?
    let distance:   CLLocationDistance

    var id: String { annotation.id }

    var waitMinutes: Int?   { enriched?.liveState?.waitMinutes }
    var isRideable:  Bool   { enriched?.liveState?.status.isRideable ?? true }
    var waitDisplay: String? { enriched?.liveState?.waitDisplay }
}

// MARK: - Ride recommendation

struct RideRecommendation {
    let rideId:      String
    let rideName:    String
    let distance:    CLLocationDistance
    let waitMinutes: Int?
    let score:       Double   // lower = better: (dist/100) + (wait ?? 30)
}

// MARK: - Filter state

struct MapFilterState: Equatable {
    var showRidden:  Bool = true
    var hideClosed:  Bool = false
    var planOnly:    Bool = false
    var onlyLowWait: Bool = false

    var isDefault: Bool { self == MapFilterState() }
}

// MARK: - Stable output cache

private struct StableOutputCache {
    var ids:         Set<String>    = []
    var latDelta:    Double         = -1
    var selectedId:  String?        = nil
    var filterState: MapFilterState = MapFilterState()
    var populated:   Bool           = false
}

// MARK: - Annotation pipeline snapshot (DEBUG only)

#if DEBUG
struct AnnotationPipelineSnapshot {
    let parkId:             String
    let parkTotal:          Int
    let wrongParkCount:     Int
    let afterCoordCheck:    Int
    let afterZoomGate:      Int
    let afterFilters:       Int
    let afterDeclutter:     Int
    /// Open count across ALL API attractions (park-scoped). Used in debug panel only.
    let openAttractionsCount: Int
    let suppressedByWrongPark:  [String]
    let suppressedByZoom:       [String]
    let suppressedByFilter:     [String]
    let suppressedByDeclutter:  [String]

    static let empty = AnnotationPipelineSnapshot(
        parkId: "", parkTotal: 0, wrongParkCount: 0,
        afterCoordCheck: 0, afterZoomGate: 0, afterFilters: 0, afterDeclutter: 0,
        openAttractionsCount: 0,
        suppressedByWrongPark: [], suppressedByZoom: [],
        suppressedByFilter: [], suppressedByDeclutter: []
    )
}
#endif

// MARK: - ViewModel

@MainActor
@Observable
final class MapViewModel {

    // ── Dependencies ───────────────────────────────────────────────────────────
    private let coordinateService: MapCoordinateService
    private(set) var waitTimeVM: WaitTimeViewModel
    var locationService: LocationService? = nil

    // ── Park ───────────────────────────────────────────────────────────────────
    var parkId: String {
        didSet {
            guard parkId != oldValue else { return }
            loadAnnotations()
            resetCamera()
        }
    }

    // ── Camera ─────────────────────────────────────────────────────────────────
    var cameraPosition: MapCameraPosition

    // ── Follow mode ────────────────────────────────────────────────────────────
    var followMode: FollowMode = .none
    private var currentlyFollowingHeading = false
    private(set) var lastKnownRegion: MKCoordinateRegion? = nil

    // ── Selection ──────────────────────────────────────────────────────────────
    var selectedRideId: String? {
        didSet { if selectedRideId != nil { sheetDetent = .peek } }
    }

    var selectedEnrichedMarker: EnrichedMarker? {
        guard let id = selectedRideId,
              let ann = annotations.first(where: { $0.id == id })
        else { return nil }
        return enrich(annotation: ann).base
    }

    var selectedRideCoordinate: CLLocationCoordinate2D? {
        guard let id = selectedRideId,
              let ann = annotations.first(where: { $0.id == id })
        else { return nil }
        return ann.coordinate
    }

    // ── Bottom sheet ───────────────────────────────────────────────────────────
    var sheetDetent: SheetDetent = .collapsed

    // ── Filters ────────────────────────────────────────────────────────────────
    var filters: MapFilterState = MapFilterState()

    // ── Annotations ────────────────────────────────────────────────────────────
    private(set) var annotations: [MapRideAnnotation] = []
    var hasCoordinates: Bool { !annotations.isEmpty }

    // ── Ridden state ───────────────────────────────────────────────────────────
    private var riddenRideNames: Set<String>       = []
    private var todaysLoggedRideNames: Set<String> = []

    // ── Planned ride IDs ──────────────────────────────────────────────────────
    private(set) var plannedRideIds: Set<String> = []

    // ── Declutter stable-output cache ─────────────────────────────────────────
    @ObservationIgnored private var stableOutputCache = StableOutputCache()
#if DEBUG
    @ObservationIgnored private var lastDisneylandLiveMatchDebugSignature = ""
#endif

    // ── Misc ───────────────────────────────────────────────────────────────────
    var isLoadingLiveData: Bool { waitTimeVM.isLoadingActivePark }
    var isZoomed: Bool = false

    // MARK: - Init

    init(
        parkId: String,
        coordinateService: MapCoordinateService = .shared,
        waitTimeVM: WaitTimeViewModel
    ) {
        self.parkId            = parkId
        self.coordinateService = coordinateService
        self.waitTimeVM        = waitTimeVM
        self.cameraPosition    = MapViewModel.defaultCamera(for: parkId)
        loadAnnotations()
    }

    func onAppear() { loadAnnotations() }

    // MARK: - Park-scoped live rides

    /// Live ride states guaranteed to match `self.parkId`.
    /// Guards against activeParkId drift when the user switches parks.
    private var parkScopedLiveRides: [LiveRideState] {
        waitTimeVM.liveRides.filter { $0.parkId == parkId }
    }

    // MARK: - Staged annotation pipeline

    /// All park annotations as RideAnnotation view models.
    /// The explicit parkId filter is Stage 1 and acts as a safety net against
    /// stale state during a rapid park switch before loadAnnotations() runs.
    var rideAnnotations: [RideAnnotation] {
        annotations
            .filter { $0.parkId == parkId }
            .map { RideAnnotation(from: $0) }
    }

    func buildVisibleAnnotations(latDelta: Double, viewportWidth: CGFloat) -> [RideAnnotation] {
        let (result, _) = runPipeline(latDelta: latDelta, viewportWidth: viewportWidth)
#if DEBUG
        logDisneylandLiveMatchingIfNeeded(finalAnnotations: result)
#endif
        return result
    }

    // MARK: - Phase 6: P1 label collision

    /// Returns the subset of P1 ride IDs (from `visible`) whose name label
    /// should be shown, applying zoom-gated suppression before the collision sweep.
    ///
    /// ── Zoom gates ───────────────────────────────────────────────────────────
    ///
    ///   latDelta > 0.018  →  wide zoom: labels are illegibly small, return []
    ///   latDelta < 0.006  →  tight zoom: rides are well-separated on screen,
    ///                         return all P1 IDs without running the sweep
    ///   0.006 ... 0.018   →  middle zoom: run the greedy collision sweep below
    ///
    /// ── Collision sweep (middle zoom only) ───────────────────────────────────
    ///
    ///   Greedy pass in stable ID order ("Park|Land|Name" key).
    ///   Each P1 annotation is accepted if no already-accepted annotation's
    ///   exclusion ellipse overlaps it in screen-point space (converted to degrees).
    ///
    ///   Exclusion ellipse thresholds:
    ///     Horizontal — 72 pt: label max-width (64 pt) + 8 pt breathing room
    ///     Vertical   — 50 pt: dot height (21–29 pt) + label height (~12 pt) + gap
    ///
    ///   At MK default zoom (latDelta ≈ 0.013, viewport ≈ 390 pt):
    ///     hThreshDeg ≈ 0.0024°  ≈ 267 m
    ///     vThreshDeg ≈ 0.0017°  ≈ 189 m
    ///
    /// Only label visibility is affected — visible ride count is unchanged.
    func p1LabelSafeIds(
        among visible:  [RideAnnotation],
        latDelta:       Double,
        viewportWidth:  CGFloat
    ) -> Set<String> {
        // ── Gate 1: wide zoom — labels are too small to read ─────────────────
        guard latDelta <= 0.018 else { return [] }

        let p1 = visible.filter { $0.priority == 1 }
        guard !p1.isEmpty else { return [] }

        // ── Gate 2: tight zoom — rides are far enough apart, skip sweep ───────
        if latDelta < 0.006 { return Set(p1.map(\.id)) }

        // ── Gate 3: guard against degenerate viewport values ──────────────────
        guard viewportWidth > 0 else { return Set(p1.map(\.id)) }

        // ── Middle zoom: greedy collision sweep ───────────────────────────────
        let degsPerPt  = latDelta / Double(viewportWidth)
        let hThreshDeg = 72.0 * degsPerPt   // horizontal: label width + padding
        let vThreshDeg = 50.0 * degsPerPt   // vertical:   dot + label + gap

        // Stable sort so the same input always produces the same accepted set,
        // preventing label toggling when live-data refreshes change array order.
        let sorted = p1.sorted { $0.id < $1.id }

        var accepted: [(lat: Double, lon: Double)] = []
        var safeIds:  Set<String>                  = []

        for annotation in sorted {
            let lat = annotation.coordinate.latitude
            let lon = annotation.coordinate.longitude

            // Accept this label only if no already-accepted label's bounding
            // box overlaps it on both axes simultaneously.
            let collides = accepted.contains { prior in
                abs(prior.lat - lat) < vThreshDeg &&
                abs(prior.lon - lon) < hThreshDeg
            }

            if !collides {
                accepted.append((lat, lon))
                safeIds.insert(annotation.id)
            }
        }
        return safeIds
    }

    private func runPipeline(
        latDelta: Double,
        viewportWidth: CGFloat
    ) -> (visible: [RideAnnotation], stages: PipelineStages) {

        let stage1    = rideAnnotations
        let wrongPark = annotations.filter { $0.parkId != parkId }
        let stage2    = stage1.filter { $0.coordinate.isValid }
        let stage3    = stage2.filter { $0.isVisible(at: latDelta) }
        let stage4    = stage3.filter { annotation in
            guard let enriched = enrichedMarker(for: annotation.id) else { return true }
            return passes(marker: enriched.base)
        }
        let stage5 = declutter(annotations: stage4, latDelta: latDelta, viewportWidth: viewportWidth)

        let stages = PipelineStages(
            wrongPark: wrongPark,
            s1: stage1, s2: stage2, s3: stage3, s4: stage4, s5: stage5
        )
        return (stage5, stages)
    }

    private struct PipelineStages {
        let wrongPark: [MapRideAnnotation]
        let s1: [RideAnnotation]
        let s2: [RideAnnotation]
        let s3: [RideAnnotation]
        let s4: [RideAnnotation]
        let s5: [RideAnnotation]
    }

    // MARK: - Selection

    func selectRide(_ id: String?) {
        withAnimation(AppMotion.standard) {
            if selectedRideId == id {
                selectedRideId = nil
                sheetDetent = .collapsed
            } else {
                selectedRideId = id
                sheetDetent = id == nil ? .collapsed : .peek
            }
        }
        if id != nil { AppHaptic.light() }
    }

    func dismiss() {
        withAnimation(AppMotion.standard) {
            selectedRideId = nil
            sheetDetent = .collapsed
        }
    }

    func setSheetDetent(_ detent: SheetDetent) {
        withAnimation(AppMotion.standard) { sheetDetent = detent }
    }

    // MARK: - Follow mode

    func cycleFollowMode() {
        switch followMode {
        case .none:          setFollowMode(.follow)
        case .follow:        setFollowMode(.followHeading)
        case .followHeading: setFollowMode(.none)
        }
    }

    func setFollowMode(_ mode: FollowMode) {
        followMode = mode
        currentlyFollowingHeading = false
        if mode == .none {
            isZoomed = true
            if let region = lastKnownRegion { cameraPosition = .region(region) }
            return
        }
        isZoomed = false
        applyFollowCamera(followsHeading: false)
    }

    func handleUserPanned() {
        guard followMode != .none else { return }
        followMode = .none
        currentlyFollowingHeading = false
        isZoomed = true
    }

    func updateCameraForLocation(_ location: CLLocation) {
        guard followMode != .none else { return }
        let isMoving     = location.speed > 0.5
        let wantsHeading = followMode == .followHeading && isMoving
        guard wantsHeading != currentlyFollowingHeading else { return }
        currentlyFollowingHeading = wantsHeading
        applyFollowCamera(followsHeading: wantsHeading)
    }

    func updateLastKnownRegion(_ region: MKCoordinateRegion) {
        lastKnownRegion = region
    }

    private func applyFollowCamera(followsHeading: Bool) {
        cameraPosition = .userLocation(
            followsHeading: followsHeading,
            fallback: MapViewModel.defaultCamera(for: parkId)
        )
    }

    // MARK: - Phase 3: Proximity

    var selectedRideProximity: RideProximity? {
        guard let dist = distanceToSelectedRide else { return nil }
        return RideProximity(distance: dist)
    }

    // MARK: - Phase 3: Declutter

    /// Density-based suppression with four interlocking mechanisms:
    ///
    /// ── Always-visible rules ──────────────────────────────────────────────────
    ///   P1 rides and the currently-selected ride are NEVER suppressed.
    ///   Sets with ≤ 8 annotations skip declutter entirely.
    ///
    /// ── Zoom-proportional geographic gate ────────────────────────────────────
    ///   `geographicDeclutterGate(for:)` — gate = latDelta × 0.065.
    ///   Two markers must pass this gate before the screen-radius check runs.
    ///   Gate is wider at wide zoom and tighter as the user zooms in.
    ///
    /// ── Lenient adaptive cluster limits ──────────────────────────────────────
    ///   `adaptiveClusterLimit(for:)` — 8 at default park zoom (≤ 0.020),
    ///   10 at mid-close zoom. Returns nil (unlimited) at tight zoom, which
    ///   also satisfies the P3-full-visibility-at-latDelta<0.006 requirement
    ///   since nil is returned for all latDelta < 0.008.
    ///
    /// ── P2 protection rule ────────────────────────────────────────────────────
    ///   `p2CanBeSuppressed(_:among:)` — a P2 ride bypasses the cluster-limit
    ///   check unless 5+ P2 neighbors already exist within 0.0005° of it.
    ///   In practice no Disney land is that dense, so P2 rides survive at all
    ///   normal park zoom levels.
    ///
    /// ── 85% visibility floor ─────────────────────────────────────────────────
    ///   `applyVisibilityFloor(kept:input:latDelta:)` — after the candidate loop,
    ///   if more than 15% of input rides were suppressed AND latDelta > 0.010,
    ///   the highest-priority suppressed rides are restored until ≥ 85% of the
    ///   input set is visible.
    ///
    /// ── Land-scoped clustering and stable output are preserved unchanged ──────
    func declutter(
        annotations: [RideAnnotation],
        latDelta: Double,
        viewportWidth: CGFloat
    ) -> [RideAnnotation] {
        guard annotations.count > 8 else { return annotations }
        guard viewportWidth > 0, latDelta > 0 else { return annotations }

        // At tight zoom, show everything — this also satisfies the P3 full-visibility
        // requirement for latDelta < 0.006 since adaptiveClusterLimit returns nil for
        // all latDelta < 0.008.
        guard let maxPerCluster = adaptiveClusterLimit(for: latDelta) else {
            stableOutputCache = StableOutputCache(
                ids:         Set(annotations.map(\.id)),
                latDelta:    latDelta,
                selectedId:  selectedRideId,
                filterState: filters,
                populated:   true
            )
            return annotations
        }

        let degreesPerPoint = latDelta / Double(viewportWidth)
        let screenRadiusDeg = 36.0 * degreesPerPoint
        let geoGate         = geographicDeclutterGate(for: latDelta)

        // Sort P1 first so they always occupy cluster slots before P2/P3 compete.
        let sorted = annotations.sorted { $0.priority < $1.priority }
        var kept: [RideAnnotation] = []

        for candidate in sorted {
            // ── Unconditional passes ───────────────────────────────────────────
            if candidate.priority == 1 || candidate.id == selectedRideId {
                kept.append(candidate)
                continue
            }

            // ── P2 protection ──────────────────────────────────────────────────
            // A P2 ride may only enter the suppression path when the local P2
            // neighborhood is genuinely dense (5+ other P2 rides within 0.0005°).
            if candidate.priority == 2 && !p2CanBeSuppressed(candidate, among: kept) {
                kept.append(candidate)
                continue
            }

            // ── Cluster density check ──────────────────────────────────────────
            // Count how many already-kept rides are:
            //   (a) within the zoom-proportional geographic gate,
            //   (b) in the same themed land, AND
            //   (c) within the adaptive screen-radius.
            let nearbyCount = kept.filter { neighbor in
                let latDiff = abs(neighbor.coordinate.latitude  - candidate.coordinate.latitude)
                let lonDiff = abs(neighbor.coordinate.longitude - candidate.coordinate.longitude)
                guard latDiff < geoGate && lonDiff < geoGate else { return false }
                guard neighbor.land == candidate.land          else { return false }
                return latDiff < screenRadiusDeg && lonDiff < screenRadiusDeg
            }.count

            if nearbyCount < maxPerCluster { kept.append(candidate) }
        }

        // ── 85% visibility floor ───────────────────────────────────────────────
        let floored = applyVisibilityFloor(kept: kept, input: annotations, latDelta: latDelta)

        return stableOutput(freshOutput: floored, validInput: annotations, latDelta: latDelta)
    }

    // MARK: - Phase 3: Zoom-proportional geographic gate

    /// Returns the maximum coordinate distance (degrees) on each axis that two
    /// markers must satisfy before the screen-radius neighbor check runs.
    ///
    /// Formula: gate = latDelta × 0.065, clamped to [0.0003°, 0.0020°].
    ///
    ///   latDelta 0.020 → gate 0.00130° ≈ 145 m  (wide zoom)
    ///   latDelta 0.013 → gate 0.00085° ≈  95 m  (MK default)
    ///   latDelta 0.010 → gate 0.00065° ≈  72 m  (mid zoom)
    ///   latDelta 0.008 → gate 0.00052° ≈  58 m  (adaptiveLimit=nil, unused)
    ///
    /// The gate is WIDER at wide zoom and TIGHTER as the user zooms in, so
    /// geographically distant rides in a large land are never counted as
    /// neighbors when the user is zoomed close.
    private func geographicDeclutterGate(for latDelta: Double) -> Double {
        let raw = latDelta * 0.065
        return min(0.0020, max(0.0003, raw))
    }

    // MARK: - Phase 3: Adaptive cluster limit

    /// Maps the current latitude delta to the maximum number of markers allowed
    /// per cluster. Returns nil when the zoom is tight enough that all markers
    /// should be shown (unlimited).
    ///
    ///   latDelta < 0.008  → nil  (tight zoom — no suppression;
    ///                             also satisfies P3 full-visibility at < 0.006)
    ///   latDelta < 0.012  → 10   (approaching medium — effectively unlimited
    ///                             for any real Disney land density)
    ///   latDelta ≤ 0.020  → 8    (default park zoom — very lenient)
    ///   latDelta > 0.020  → 5    (wide zoom — light suppression only)
    private func adaptiveClusterLimit(for latDelta: Double) -> Int? {
        if latDelta < 0.008  { return nil }
        if latDelta < 0.012  { return 10 }
        if latDelta <= 0.020 { return 8 }
        return 5
    }

    // MARK: - Phase 3: P2 protection

    /// Returns true when a P2 candidate has accumulated enough P2 neighbors in
    /// `kept` that suppression is warranted; returns false otherwise (keeping
    /// the ride unconditionally).
    ///
    /// A P2 ride may only be suppressed when 5+ other P2 rides are already in
    /// `kept` within 0.0005° (≈ 55 m) on each axis. No Disney land has this
    /// density under normal conditions, so P2 rides are effectively never
    /// suppressed at default park zoom.
    private func p2CanBeSuppressed(_ candidate: RideAnnotation, among kept: [RideAnnotation]) -> Bool {
        let nearbyP2Count = kept.filter { neighbor in
            guard neighbor.priority == 2 else { return false }
            let latDiff = abs(neighbor.coordinate.latitude  - candidate.coordinate.latitude)
            let lonDiff = abs(neighbor.coordinate.longitude - candidate.coordinate.longitude)
            return latDiff < 0.0005 && lonDiff < 0.0005
        }.count
        return nearbyP2Count >= 5
    }

    // MARK: - Phase 3: 85% visibility floor

    /// After the main declutter loop, ensures no more than 15% of `input` rides
    /// were suppressed. Only active at medium-to-wide zoom (latDelta > 0.010).
    ///
    /// If the floor is not met, the highest-priority suppressed rides (P1 first,
    /// then P2, then P3) are restored until ≥ 85% of `input.count` are in `kept`.
    private func applyVisibilityFloor(
        kept: [RideAnnotation],
        input: [RideAnnotation],
        latDelta: Double
    ) -> [RideAnnotation] {
        // Only enforce at medium-to-wide zoom.
        guard latDelta > 0.010 else { return kept }

        let minVisible = Int(ceil(Double(input.count) * 0.85))
        guard kept.count < minVisible else { return kept }

        let keptIds    = Set(kept.map(\.id))
        let suppressed = input
            .filter { !keptIds.contains($0.id) }
            .sorted { $0.priority < $1.priority }   // highest-priority first

        var result = kept
        for ride in suppressed {
            guard result.count < minVisible else { break }
            result.append(ride)
        }
        return result
    }

    // MARK: - Phase 3: Stable output

    /// Compares `freshOutput` against the last accepted output and decides
    /// whether to accept the new set or prefer the cached one to suppress flicker.
    private func stableOutput(
        freshOutput: [RideAnnotation],
        validInput:  [RideAnnotation],
        latDelta:    Double
    ) -> [RideAnnotation] {
        let freshIds = Set(freshOutput.map(\.id))
        let validIds = Set(validInput.map(\.id))

        let noCache        = !stableOutputCache.populated
        let zoomShifted    = abs(latDelta - stableOutputCache.latDelta) > 0.001
        let selectionMoved = stableOutputCache.selectedId != selectedRideId
        let filterChanged  = stableOutputCache.filterState != filters

        if noCache || zoomShifted || selectionMoved || filterChanged {
            stableOutputCache = StableOutputCache(
                ids:         freshIds,
                latDelta:    latDelta,
                selectedId:  selectedRideId,
                filterState: filters,
                populated:   true
            )
            return freshOutput
        }

        let cachedIds = stableOutputCache.ids.intersection(validIds)
        let added     = freshIds.subtracting(cachedIds)
        let removed   = cachedIds.subtracting(freshIds)

        if removed.isEmpty {
            let merged = freshIds.union(cachedIds)
            stableOutputCache.ids = merged
            return validInput.filter { merged.contains($0.id) }
        }

        let removedAnnotations = validInput.filter { removed.contains($0.id) }
        let hasCriticalRemoval = removedAnnotations.contains {
            $0.priority == 1 || $0.id == selectedRideId
        }

        if hasCriticalRemoval {
            stableOutputCache = StableOutputCache(
                ids:         freshIds,
                latDelta:    latDelta,
                selectedId:  selectedRideId,
                filterState: filters,
                populated:   true
            )
            return freshOutput
        }

        let stableIds = cachedIds.union(added)
        stableOutputCache.ids = stableIds
        return validInput.filter { stableIds.contains($0.id) }
    }

    // MARK: - Phase 4: Nearby rides

    func nearbyRides(
        limit: Int = 5,
        maxDistance: CLLocationDistance = 800
    ) -> [NearbyRide] {
        guard let userLoc = locationService?.userLocation else { return [] }
        return rideAnnotations
            .compactMap { annotation -> NearbyRide? in
                guard annotation.coordinate.isValid else { return nil }
                let loc  = CLLocation(latitude:  annotation.coordinate.latitude,
                                      longitude: annotation.coordinate.longitude)
                let dist = userLoc.distance(from: loc)
                guard dist <= maxDistance else { return nil }
                return NearbyRide(
                    annotation: annotation,
                    enriched:   enrichedMarker(for: annotation.id)?.base,
                    distance:   dist
                )
            }
            .sorted { $0.distance < $1.distance }
            .prefix(limit)
            .map { $0 }
    }

    // MARK: - Phase 4: Dominant land

    func dominantLand(among annotations: [RideAnnotation]) -> String? {
        guard annotations.count >= 2 else { return nil }
        let counts = Dictionary(grouping: annotations, by: \.land).mapValues(\.count)
        guard let (topLand, topCount) = counts.max(by: { $0.value < $1.value }) else { return nil }
        let otherMax = counts.filter { $0.key != topLand }.values.max() ?? 0
        guard topCount > otherMax else { return nil }
        return topLand
    }

    // MARK: - Phase 4: Best next ride

    var bestNextRide: RideRecommendation? {
        guard let userLoc = locationService?.userLocation else { return nil }
        return annotations
            .filter { $0.parkId == parkId }
            .compactMap { ann -> RideRecommendation? in
                guard let enrichedWS = enrichedMarker(for: ann.id) else { return nil }
                let e = enrichedWS.base
                guard let live = e.liveState,
                      live.status.isRideable,
                      !e.isRidden
                else { return nil }
                let dist  = userLoc.distance(from: CLLocation(latitude:  ann.latitude,
                                                              longitude: ann.longitude))
                let wait  = live.waitMinutes
                let score = (dist / 100.0) + Double(wait ?? 30)
                return RideRecommendation(
                    rideId:      ann.id,
                    rideName:    ann.rideName,
                    distance:    dist,
                    waitMinutes: wait,
                    score:       score
                )
            }
            .min { $0.score < $1.score }
    }

    // MARK: - Camera helpers

    func framePark() { resetCamera() }

    func centerOnSelectedRide() {
        guard let id = selectedRideId,
              let ann = annotations.first(where: { $0.id == id })
        else { return }
        centerOn(annotation: ann)
    }

    func centerOn(coordinate: CLLocationCoordinate2D, span: CLLocationDegrees = 0.002) {
        withAnimation(AppMotion.standard) {
            cameraPosition = .region(MKCoordinateRegion(
                center: coordinate,
                span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
            ))
            isZoomed = true
        }
    }

    func centerOn(annotation: MapRideAnnotation) {
        withAnimation(AppMotion.standard) {
            cameraPosition = .region(MKCoordinateRegion(
                center: annotation.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.002, longitudeDelta: 0.002)
            ))
            isZoomed = true
        }
    }

    // MARK: - Public lookup helpers

    func enrichedMarker(for id: String) -> EnrichedMarkerWithSelection? {
        guard let ann = annotations.first(where: { $0.id == id }) else { return nil }
        return enrich(annotation: ann)
    }

    var distanceToSelectedRide: CLLocationDistance? {
        guard let userLoc = locationService?.userLocation,
              let id = selectedRideId,
              let ann = annotations.first(where: { $0.id == id })
        else { return nil }
        return userLoc.distance(from: CLLocation(latitude: ann.latitude, longitude: ann.longitude))
    }

    // MARK: - State update hooks

    func updateRiddenState(rides: [Ride]) {
        let today = Calendar.current.startOfDay(for: Date())
        var ridden: Set<String> = []
        var logged:  Set<String> = []
        for ride in rides {
            let key = ride.name.lowercased()
            if ride.isRidden { ridden.insert(key) }
            if ride.logs.contains(where: {
                Calendar.current.startOfDay(for: $0.date) == today
            }) { logged.insert(key) }
        }
        riddenRideNames       = ridden
        todaysLoggedRideNames = logged
    }

    func updatePlannedRideIds(_ ids: Set<String>) {
        plannedRideIds = ids
    }

    func toggleFilter(_ keyPath: WritableKeyPath<MapFilterState, Bool>) {
        filters[keyPath: keyPath].toggle()
        if let id = selectedRideId,
           let ann = annotations.first(where: { $0.id == id }),
           !passes(marker: enrich(annotation: ann).base) {
            dismiss()
        }
    }

    // MARK: - Canvas / composition support

    var currentComposition: ParkComposition {
        ParkCompositionRegistry.composition(for: parkId)
    }

    func fitScale(for viewportSize: CGSize) -> CGFloat {
        let comp = currentComposition
        let dv   = comp.defaultViewport
        return min(
            viewportSize.width  / (comp.contentSize.width  * dv.width),
            viewportSize.height / (comp.contentSize.height * dv.height)
        )
    }

    func resetCamera() {
        followMode = .none
        currentlyFollowingHeading = false
        withAnimation(.easeInOut) {
            selectedRideId = nil
            sheetDetent = .collapsed
            cameraPosition = MapViewModel.defaultCamera(for: parkId)
            isZoomed = false
        }
    }

    // MARK: - Private helpers

    private func loadAnnotations() {
        annotations = coordinateService.annotations(for: parkId)
        stableOutputCache = StableOutputCache()
    }

    private func enrich(annotation: MapRideAnnotation) -> EnrichedMarkerWithSelection {
        let live = liveState(for: annotation)
        let nameLower = annotation.rideName.lowercased()
        let isRidden  = riddenRideNames.contains(nameLower)
            || riddenRideNames.contains(where: { nameLower.contains($0) || $0.contains(nameLower) })
        let isLogged  = todaysLoggedRideNames.contains(nameLower)
            || todaysLoggedRideNames.contains(where: { nameLower.contains($0) || $0.contains(nameLower) })
        let isPlanned = plannedRideIds.contains(annotation.id)
        let marker = EnrichedMarker(
            annotation:    annotation,
            liveState:     live,
            isRidden:      isRidden,
            isLoggedToday: isLogged,
            isPlanned:     isPlanned
        )
        return EnrichedMarkerWithSelection(base: marker, selected: annotation.id == selectedRideId)
    }

    private func liveState(for annotation: MapRideAnnotation) -> LiveRideState? {
        if let exactIdMatch = parkScopedLiveRides.first(where: { $0.id == annotation.id }) {
            return exactIdMatch
        }

        return parkScopedLiveRides.first {
            Self.liveNamesMatch(annotation.rideName, $0.name)
        }
    }

    private static func liveNamesMatch(_ lhs: String, _ rhs: String) -> Bool {
        let lhsKeys = liveMatchKeys(for: lhs)
        let rhsKeys = liveMatchKeys(for: rhs)

        for lhsKey in lhsKeys {
            for rhsKey in rhsKeys {
                if lhsKey == rhsKey || lhsKey.contains(rhsKey) || rhsKey.contains(lhsKey) {
                    return true
                }
            }
        }
        return false
    }

    private static func liveMatchKeys(for name: String) -> Set<String> {
        let normalized = WaitTimeViewModel.normalizedForMatching(name)
        var keys: Set<String> = [normalized]

        // Disney California Adventure rotates the public Soarin' name; the live
        // feed may report "Soarin' Over California" while the local catalog keeps
        // the canonical ride as "Soarin' Around the World".
        if normalized.hasPrefix("soarin ") || normalized == "soarin" {
            keys.insert("soarin")
        }

        return keys
    }

    private func passes(marker: EnrichedMarker) -> Bool {
        if !filters.showRidden  && marker.isRidden { return false }
        if filters.hideClosed,
           let live = marker.liveState,
           !live.status.isRideable { return false }
        if filters.planOnly && !marker.isPlanned { return false }
        if filters.onlyLowWait,
           let mins = marker.liveState?.waitMinutes,
           mins >= 30 { return false }
        return true
    }

    // MARK: - Default cameras

    static func defaultCamera(for parkId: String) -> MapCameraPosition {
        let (center, span) = parkCenterAndSpan(for: parkId)
        return .region(MKCoordinateRegion(
            center: center,
            span: MKCoordinateSpan(latitudeDelta: span, longitudeDelta: span)
        ))
    }

    static func defaultSpan(for parkId: String) -> CLLocationDegrees {
        parkCenterAndSpan(for: parkId).1
    }

    // MARK: - HUD derived state

    var hasLiveData:    Bool { !parkScopedLiveRides.isEmpty }
    var sheetIsExpanded: Bool { sheetDetent != .collapsed }

    private var rideableWithWaits: [LiveRideState] {
        parkScopedLiveRides.filter { $0.status.isRideable && $0.waitMinutes != nil }
    }

    var avgWaitMinutes: Int? {
        let waits = rideableWithWaits.compactMap(\.waitMinutes)
        guard !waits.isEmpty else { return nil }
        return waits.reduce(0, +) / waits.count
    }

    // ── All-API-attractions counts (denominator = everything the backend returned) ──
    /// Number of rideable API attractions for the active park. Used in the debug
    /// panel to show how many of the backend's ~33 EPCOT entries are open.
    var openAttractionsCount:  Int { parkScopedLiveRides.filter { $0.status.isRideable }.count }
    /// Total API attractions returned for the active park (may exceed the curated
    /// seeder count because the backend includes shows, food-ordering queues, etc.).
    var totalAttractionsCount: Int { parkScopedLiveRides.count }

    // ── Curated-ride counts (denominator = MapCoordinates.json / seeder pins) ──
    /// Number of curated annotation pins for the active park (matches seeder rides).
    var totalRidesCount: Int {
        annotations.filter { $0.parkId == parkId }.count
    }
    /// Number of curated rides that have a rideable live state.
    /// Rides with no live-data match are counted as closed (not open).
    var openRidesCount: Int {
        annotations
            .filter { $0.parkId == parkId }
            .filter { ann in enrich(annotation: ann).base.liveState?.status.isRideable ?? false }
            .count
    }

    var shortestWaitRide: String? {
        rideableWithWaits
            .min { ($0.waitMinutes ?? Int.max) < ($1.waitMinutes ?? Int.max) }?
            .name
    }

    private static func parkCenterAndSpan(for parkId: String) -> (CLLocationCoordinate2D, Double) {
        switch parkId {
        case "magic-kingdom":        return (.init(latitude: 28.4195, longitude: -81.5812), 0.013)
        case "epcot":                return (.init(latitude: 28.3730, longitude: -81.5494), 0.016)
        case "hollywood-studios":    return (.init(latitude: 28.3574, longitude: -81.5605), 0.011)
        case "animal-kingdom":       return (.init(latitude: 28.3580, longitude: -81.5900), 0.018)
        case "disneyland":           return (.init(latitude: 33.8112, longitude: -117.9190), 0.011)
        case "california-adventure": return (.init(latitude: 33.8093, longitude: -117.9189), 0.010)
        default:                     return (.init(latitude: 28.4195, longitude: -81.5812), 0.015)
        }
    }
}

// MARK: - DEBUG: Pipeline snapshot

#if DEBUG
extension MapViewModel {

    private func logDisneylandLiveMatchingIfNeeded(finalAnnotations: [RideAnnotation]) {
        guard parkId == "disneyland" || parkId == "california-adventure" else { return }

        let parkAnnotations = annotations.filter { $0.parkId == parkId }
        let finalAnnotationIds = Set(finalAnnotations.map(\.id))
        let finalMapAnnotations = parkAnnotations.filter { finalAnnotationIds.contains($0.id) }

        let matched = finalMapAnnotations.compactMap { annotation -> (MapRideAnnotation, LiveRideState)? in
            guard let live = liveState(for: annotation) else { return nil }
            return (annotation, live)
        }
        let matchedIds = Set(matched.map { $0.0.id })
        let unmatched = finalMapAnnotations.filter { !matchedIds.contains($0.id) }

        let unmatchedSignature = unmatched
            .map { "\($0.id)=\($0.rideName)" }
            .sorted()
            .joined(separator: "|")
        let signature = [
            parkId,
            "\(parkScopedLiveRides.count)",
            "\(parkAnnotations.count)",
            "\(finalMapAnnotations.count)",
            "\(matched.count)",
            unmatchedSignature
        ].joined(separator: "::")

        guard signature != lastDisneylandLiveMatchDebugSignature else { return }
        lastDisneylandLiveMatchDebugSignature = signature

        print("""
        ┌─ 🎢 Disneyland Live Matching [\(parkId)] ─────────────────────
        │  Park-scoped live items:      \(parkScopedLiveRides.count)
        │  Park ride annotations:       \(parkAnnotations.count)
        │  Final ride annotations:      \(finalMapAnnotations.count)
        │  Successful live matches:     \(matched.count)
        │  Unmatched final annotations: \(unmatched.count)
        └──────────────────────────────────────────────────────────────
        """)

        if !unmatched.isEmpty {
            let details = unmatched
                .map { "\($0.id) — \($0.rideName)" }
                .joined(separator: "\n")
            print("  ↳ ⚠︎ Disneyland unmatched ride IDs/names:\n\(details)")
        }
    }

    func pipelineSnapshot(
        latDelta: Double,
        viewportWidth: CGFloat
    ) -> AnnotationPipelineSnapshot {
        let (_, stages) = runPipeline(latDelta: latDelta, viewportWidth: viewportWidth)

        let zoomedOutIds   = Set(stages.s2.map(\.id)).subtracting(Set(stages.s3.map(\.id)))
        let filteredOutIds = Set(stages.s3.map(\.id)).subtracting(Set(stages.s4.map(\.id)))
        let declutteredIds = Set(stages.s4.map(\.id)).subtracting(Set(stages.s5.map(\.id)))

        return AnnotationPipelineSnapshot(
            parkId:                 parkId,
            parkTotal:              stages.s1.count,
            wrongParkCount:         stages.wrongPark.count,
            afterCoordCheck:        stages.s2.count,
            afterZoomGate:          stages.s3.count,
            afterFilters:           stages.s4.count,
            afterDeclutter:         stages.s5.count,
            openAttractionsCount:   openAttractionsCount,
            suppressedByWrongPark:  stages.wrongPark.map(\.rideName),
            suppressedByZoom:       stages.s2.filter { zoomedOutIds.contains($0.id) }.map(\.name),
            suppressedByFilter:     stages.s3.filter { filteredOutIds.contains($0.id) }.map(\.name),
            suppressedByDeclutter:  stages.s4.filter { declutteredIds.contains($0.id) }.map(\.name)
        )
    }

    func logPipeline(latDelta: Double, viewportWidth: CGFloat) {
        let snap = pipelineSnapshot(latDelta: latDelta, viewportWidth: viewportWidth)
        let gate = String(format: "%.5f", geographicDeclutterGate(for: latDelta))
        let lim  = adaptiveClusterLimit(for: latDelta).map { "\($0)" } ?? "nil"
        print("""
        ┌─ 🗺  Annotation Pipeline [\(snap.parkId)] ─────────────────────────
        │  Stage 1 — Park total:       \(snap.parkTotal)  (wrong-park: \(snap.wrongParkCount))
        │  Stage 2 — Valid coords:     \(snap.afterCoordCheck)
        │  Stage 3 — After zoom gate:  \(snap.afterZoomGate)  (latΔ \(String(format: "%.4f", latDelta)))
        │  Stage 4 — After filters:    \(snap.afterFilters)
        │  Stage 5 — Final visible:    \(snap.afterDeclutter)  (geoGate \(gate)  limit \(lim))
        │  Open (all API attractions):  \(snap.openAttractionsCount) / \(snap.parkTotal)
        └───────────────────────────────────────────────────────────────────
        """)
        if !snap.suppressedByWrongPark.isEmpty {
            print("  ↳ ⚠︎ Wrong-park (\(snap.suppressedByWrongPark.count)): \(snap.suppressedByWrongPark.joined(separator: " · "))")
        }
        if !snap.suppressedByZoom.isEmpty {
            print("  ↳ Zoom (\(snap.suppressedByZoom.count)): \(snap.suppressedByZoom.joined(separator: " · "))")
        }
        if !snap.suppressedByFilter.isEmpty {
            print("  ↳ Filter (\(snap.suppressedByFilter.count)): \(snap.suppressedByFilter.joined(separator: " · "))")
        }
        if !snap.suppressedByDeclutter.isEmpty {
            print("  ↳ Declutter (\(snap.suppressedByDeclutter.count)): \(snap.suppressedByDeclutter.joined(separator: " · "))")
        }
    }
}
#endif
