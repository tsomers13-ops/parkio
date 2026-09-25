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
only in DEBUG builds as a fallback); that mock asset is untouched by this
change. `ParkMapViewModel.magicKingdomPins` normalized (0–1) coordinates in
this commit are calibrated against `magic_kingdom_map` (this real artwork),
using the numbered directory markers printed on the source map as ground
truth — not against the abstract mock.

Note: `ParkMapCanvasView`/`ParkMapBackgroundView` (the view that renders this
asset via `ParkMapViewModel`) is not currently wired into the shipping Maps
tab (see header comment in `MapTabView.swift`) — `RealMapScreen`
(MapKit-based, GPS lat/lon from `MapCoordinates.json`) is what's live. This
asset and its pin calibration are therefore inert in the current build, same
as the existing mock assets for every other park.
