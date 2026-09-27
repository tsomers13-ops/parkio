# magic_kingdom_map — asset provenance

Source: `MK-map.webp` (official Walt Disney World Magic Kingdom guest guide map),
2500×1141px, supplied by the user for this task. Not committed to the repo —
only the derived crop below is.

## Crop

The source image is a composite: a map illustration on the left and four
directory/legend text columns (land guest-services lists + accessibility
legend) on the right. Only the map illustration was kept.

- Crop box (pixels, top-left origin, against the 2500×1141 source): `(0, 0, 1160, 1141)`.
- Boundary was located programmatically: sampled column color at multiple rows
  and found the map-illustration-to-directory-panel transition is a consistent
  vertical edge at x≈1160–1165 (green/blue map pixels give way to the
  directory panels' cream background at every sampled row). No content was
  cropped from the top, left, or bottom edges — the map illustration touches
  all three of those edges in the source.
- Resulting crop: 1160×1141px, saved as `mk_map_crop.png` (not committed;
  intermediate working file), then resized with Lanczos resampling to the
  three catalog scales below. The 1x/2x/3x sizes preserve the crop's aspect
  ratio (1160:1141 ≈ 1.0167) to within 0.1%.

## Generated files

| File | Size |
|---|---|
| `magic_kingdom_map.png` (1x) | 390×384 |
| `magic_kingdom_map@2x.png` | 780×768 |
| `magic_kingdom_map@3x.png` | 1170×1152 |

Generation is deterministic: same source crop + Lanczos resize to the same
target sizes reproduces byte-identical output.

## Naming / wiring

Follows the documented convention in `ParkMapViewModel.mapImageName`
(`Parkio/Features/Map/ViewModels/ParkMapViewModel.swift`): production asset
name is `"<parkId>_map"` → `magic_kingdom_map`. This is a sibling of the
pre-existing `magic_kingdom_map_mock` imageset (abstract placeholder art used
as a DEBUG-only fallback for parks with no production art yet); that mock
asset is untouched by this change. `mapImageName` resolves the production
asset first — in both DEBUG and release — and only falls back to the mock in
DEBUG when no production asset exists (see `MapImageResolution.swift` for the
unit-tested decision logic). Magic Kingdom always has a production asset, so
it is never shown the mock. `ParkMapPinData.magicKingdomPins` normalized
(0–1) coordinates are calibrated against `magic_kingdom_map` (this real
artwork), using the numbered directory markers printed on the source map as
ground truth — not against the abstract mock.

## Live wiring

`MapTabView` routes the Maps tab's surface per park via
`MapRoutingDecision.renderMode(forParkId:)`: Magic Kingdom renders
`ParkMapCanvasView`/`ParkMapBackgroundView` (this asset, as an interactive
pan/zoom image canvas); every other park keeps `RealMapScreen` (MapKit-based,
GPS lat/lon from `MapCoordinates.json`). Both surfaces share the same
`MapViewModel`, so ride selection and the bottom sheet behave identically
either way.

Every `ParkMapPin`'s `internalRideId` is a short calibration handle (e.g.
`"mk|space-mountain"`, `"mk|dining|be-our-guest"`) — it does not match the
canonical `"Park|Land|Name"` stableID scheme `RideMasterData`, SwiftData
`Ride` records, `MapRideAnnotation`, and `DiningVenueKeys` all use.
`MapPinIdentityResolver` (pure, unit-tested) plus `ParkMapPinResolution.swift`
(the real-data wiring) resolve a pin's display name to that canonical
stableID. `ParkMapCanvasView.handlePinTap` then routes on what the pin
represents:
  - **Attraction pins** (have a `MapCoordinates.json` GPS annotation) —
    `MapViewModel.selectRide(stableID)`, the same ride bottom sheet
    (`RideMapBottomSheetView`) RealMapScreen uses.
  - **Dining pins** (no GPS annotation — dining venues are not placed via
    fake coordinates) — resolved straight to their SwiftData `Ride` record
    and presented via `RideDetailView`, the same dining detail sheet
    (including `CommunityRatingSection` via the generated venueKey) the
    EPCOT/Hollywood Studios dining list already uses.

All 31 Magic Kingdom dining pins resolve to a real, rateable venueKey
locally (see `MagicKingdomMapDiningRatingEligibilityTests`); the live ratings
backend (`parkio.info`) has not yet been deployed with the Magic Kingdom
venueKeys this task minted, so `GET /api/dining/mk-*/ratings/` currently
404s ("Unknown dining venue") until that separate deploy ships —
`CommunityRatingSection` fails soft on that (renders nothing) rather than
showing an error, identically to how it behaves for any newly-minted venueKey
before its first backend deploy.
