// ParkMapBackgroundView.swift — Abstract placeholder map backgrounds.
//
// Visual design system:
//   • Base canvas: adaptive warm parchment (light) / deep charcoal (dark).
//     Each park has a subtly different parchment tint (neutral, cool-tinted,
//     amber, earthy) to preserve per-park personality.
//   • Zones: semi-transparent rounded districts rendered with a directional
//     gradient (lighter top 1.45×, darker base 0.62×). Reduced fillOpacity
//     (0.24–0.26) keeps zones district-like rather than tile-like. Dual
//     shadows retain zone elevation off the canvas.
//   • Labels: two-shadow halo technique — zone-tinted shadow anchors the
//     label to its region; white glow ensures readability against the fill.
//     Warm dark brown in light mode; white in dark mode.
//   • Dot grid: two-scale pattern (fine 22pt + coarse 66pt). Warm-charcoal
//     dots on parchment in light mode; park-accent-tinted dots in dark mode.
//   • Atmospheric overlays: top/bottom fades tinted with canvasColor naturally
//     blend to parchment (light) or charcoal (dark). Center bloom unchanged.
//
// Architecture contract (unchanged):
//   Zone coordinates (x, y, w, h) are normalized 0–1 and match ParkMapPin positions.
//   Do NOT move zone bounds — move them only when pins move.
//   ParkMapViewModel.hasMapImage = true → this file is bypassed entirely.
//
// Type-checker safety:
//   Every @ViewBuilder body is a single expression.
//   Screen coordinates are computed properties, never let bindings inside body.
//   ZoneView is a separate struct (keeps ForEach closure minimal).

import SwiftUI

// MARK: - Top-level switcher
//
// Accepts a ParkComposition from the canvas layer.
// contentSize is owned by the composition — ParkMapCanvasView no longer derives
// canvas dimensions from the viewport; it reads composition.contentSize directly.
//
// hasMapImage path: unchanged — real image asset fills composition.contentSize.
// Composition path: CompositionMapCanvas renders MapBackgroundShapes via Canvas,
//   then layers the existing dot-grid texture + bloom + vignette on top.

struct ParkMapBackgroundView: View {
    @Environment(ParkMapViewModel.self) private var parkMapVM

    /// Authored composition for the current park.
    /// Passed by ParkMapCanvasView.canvasStack; never read from environment.
    let composition: ParkComposition

    var body: some View {
        if parkMapVM.hasMapImage {
            realMapImage
        } else {
            CompositionMapCanvas(composition: composition)
        }
    }

    private var realMapImage: some View {
        Image(parkMapVM.mapImageName)
            .resizable()
            .scaledToFill()
            .frame(
                width:  composition.contentSize.width,
                height: composition.contentSize.height
            )
            .clipped()
    }
}

// MARK: - Composition canvas renderer

/// Renders a ParkComposition as the map background.
/// Replaces PlaceholderMapCanvas. Preserves dot-grid, bloom, and vignette layers.
private struct CompositionMapCanvas: View {
    let composition: ParkComposition

    private var cs: CGSize { composition.contentSize }

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Layer 1: warm parchment base ───────────────────────────────
            MapTokens.canvasBase

            // ── Layer 2: authored park shapes ──────────────────────────────
            Canvas { context, size in
                for shape in composition.orderedShapes {
                    renderShape(shape, in: context, canvasSize: size)
                }
            }

            // ── Layer 3: two-scale dot-grid texture (preserved) ────────────
            DotGridView(
                color: Color(red: 0.25, green: 0.20, blue: 0.15),
                size: cs
            )

            // ── Layer 4: center bloom ──────────────────────────────────────
            RadialGradient(
                colors: [Color.white.opacity(0.04), .clear],
                center: .center,
                startRadius: 0,
                endRadius:   cs.width * 0.55
            )

            // ── Layer 5: edge vignette ─────────────────────────────────────
            RadialGradient(
                colors: [.clear, MapTokens.canvasBase.opacity(0.40)],
                center: .center,
                startRadius: cs.width * 0.22,
                endRadius:   cs.width * 0.88
            )
        }
        .frame(width: cs.width, height: cs.height)
    }

    // MARK: - Shape rendering

    private func renderShape(
        _ shape: MapBackgroundShape,
        in context: GraphicsContext,
        canvasSize: CGSize
    ) {
        var ctx = context
        ctx.opacity = shape.fillOpacity
        let path = resolvedPath(for: shape.geometry, canvasSize: canvasSize)
        ctx.fill(path, with: .color(shape.fillColor))

        // Soft inner stroke on solid land masses only — adds subtle edge definition.
        if shape.type == .landMass || shape.type == .hub {
            var strokeCtx = context
            strokeCtx.opacity = shape.fillOpacity * 0.18
            strokeCtx.stroke(path, with: .color(shape.fillColor), lineWidth: 1.5)
        }
    }

    // MARK: - Path resolution (normalized → canvas points)

    private func resolvedPath(
        for geometry: ShapeGeometry,
        canvasSize: CGSize
    ) -> Path {
        switch geometry {
        case .rect(let r):
            return Path(denorm(r, canvasSize))
        case .roundedRect(let r, let radius):
            return Path(
                roundedRect: denorm(r, canvasSize),
                cornerRadius: radius,
                style: .continuous
            )
        case .ellipse(let r):
            return Path(ellipseIn: denorm(r, canvasSize))
        case .polygon(let points):
            var path = Path()
            let abs = points.map {
                CGPoint(x: $0.x * canvasSize.width, y: $0.y * canvasSize.height)
            }
            guard let first = abs.first else { return path }
            path.move(to: first)
            abs.dropFirst().forEach { path.addLine(to: $0) }
            path.closeSubpath()
            return path
        }
    }

    /// Converts a normalized CGRect to canvas-space points.
    private func denorm(_ r: CGRect, _ size: CGSize) -> CGRect {
        CGRect(
            x:      r.minX * size.width,
            y:      r.minY * size.height,
            width:  r.width  * size.width,
            height: r.height * size.height
        )
    }
}

// MARK: - Zone model

struct MapZone: Identifiable {
    let id: String
    let label: String
    let icon: String?
    let x: Double
    let y: Double
    let w: Double
    let h: Double
    let fill: Color
    /// Target 0.24–0.26 — keeps zones as tinted districts, not solid tiles.
    var fillOpacity: Double  = 0.25
    var labelOpacity: Double = 0.60

    func screenRect(in size: CGSize) -> CGRect {
        CGRect(x: x * size.width, y: y * size.height,
               width: w * size.width, height: h * size.height)
    }
}

// MARK: - Park layout

struct ParkLayout {
    let parkId: String
    let canvasColor: Color
    let accentColor: Color
    let zones: [MapZone]

    static func layout(for parkId: String) -> ParkLayout {
        switch parkId {
        case "magic-kingdom":         return .magicKingdom
        case "epcot":                 return .epcot
        case "hollywood-studios":     return .hollywoodStudios
        case "animal-kingdom":        return .animalKingdom
        case "disneyland":            return .disneyland
        case "california-adventure":  return .californiaAdventure
        default:                      return .magicKingdom
        }
    }
}

// MARK: - Main canvas renderer

private struct PlaceholderMapCanvas: View {
    let layout: ParkLayout
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {

            // ── Layer 1: base canvas ─────────────────────────────────────
            // Adaptive parchment (light) / charcoal (dark) per park.
            layout.canvasColor.ignoresSafeArea()

            // ── Layer 2: two-scale dot grid texture ──────────────────────
            // Light: warm-charcoal dots on parchment.
            // Dark: park-accent-tinted dots on charcoal.
            DotGridView(color: layout.accentColor, size: size)

            // ── Layer 3: center bloom — subtle brightness at map center ──
            // Mimics the "hotspot" in Maps satellite view; draws eye inward.
            RadialGradient(
                colors: [Color.white.opacity(0.045), .clear],
                center: .center,
                startRadius: 0,
                endRadius:   size.width * 0.55
            )

            // ── Layer 4: edge vignette — keeps center brighter than edges ─
            RadialGradient(
                colors: [.clear, layout.canvasColor.opacity(0.48)],
                center: .center,
                startRadius: size.width * 0.20,
                endRadius:   size.width * 0.90
            )

            // ── Layer 5: zone regions ────────────────────────────────────
            ForEach(layout.zones) { zone in
                ZoneView(zone: zone, canvasSize: size)
            }

            // ── Layer 6: atmospheric top fade ────────────────────────────
            // Deepens the sky / top edge; adds distance and framing.
            LinearGradient(
                colors: [layout.canvasColor.opacity(0.60), .clear],
                startPoint: .top,
                endPoint: UnitPoint(x: 0.5, y: 0.20)
            )
            .allowsHitTesting(false)

            // ── Layer 7: atmospheric bottom fade ─────────────────────────
            LinearGradient(
                colors: [.clear, layout.canvasColor.opacity(0.42)],
                startPoint: UnitPoint(x: 0.5, y: 0.78),
                endPoint: .bottom
            )
            .allowsHitTesting(false)
        }
        .frame(width: size.width, height: size.height)
        .clipped()
    }
}

// MARK: - Two-scale dot grid

/// Two overlapping dot patterns create tactile depth:
/// fine grid (22pt, 3.5%) for close-up texture +
/// coarse grid (66pt, 7%) for long-range visual rhythm.
private struct DotGridView: View {
    let color: Color
    let size: CGSize

    var body: some View {
        Canvas { ctx, sz in
            // Fine pattern — close surface texture
            let fineSpacing: CGFloat  = 22
            let fineRadius: CGFloat   = 0.85
            var col: CGFloat = fineSpacing
            while col < sz.width {
                var row: CGFloat = fineSpacing
                while row < sz.height {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: col - fineRadius, y: row - fineRadius,
                                               width: fineRadius * 2, height: fineRadius * 2)),
                        with: .color(color.opacity(0.035))
                    )
                    row += fineSpacing
                }
                col += fineSpacing
            }
            // Coarse pattern — distance rhythm
            let coarseSpacing: CGFloat = 66
            let coarseRadius: CGFloat  = 1.5
            col = coarseSpacing / 2
            while col < sz.width {
                var row: CGFloat = coarseSpacing / 2
                while row < sz.height {
                    ctx.fill(
                        Path(ellipseIn: CGRect(x: col - coarseRadius, y: row - coarseRadius,
                                               width: coarseRadius * 2, height: coarseRadius * 2)),
                        with: .color(color.opacity(0.07))
                    )
                    row += coarseSpacing
                }
                col += coarseSpacing
            }
        }
        .frame(width: size.width, height: size.height)
        .allowsHitTesting(false)
    }
}

// MARK: - Zone view

/// Renders one park region with gradient fill, dual shadows, and a halo label.
/// Separate struct keeps the ForEach body a single expression (type-checker safety).
private struct ZoneView: View {
    let zone: MapZone
    let canvasSize: CGSize

    @Environment(\.colorScheme) private var colorScheme

    // ── Screen-space geometry (computed, never let in body) ───────────────────

    private var rect: CGRect  { zone.screenRect(in: canvasSize) }
    private var midX: CGFloat { rect.midX }
    private var midY: CGFloat { rect.midY }

    /// Corner radius — organic terrain regions, not boxy cards.
    /// Clamped to 24pt so small zones don't become near-circles.
    private var cornerRadius: CGFloat {
        min(min(rect.width, rect.height) * 0.30, 24)
    }

    /// Font scales with zone width; tight floor prevents illegibility in narrow zones.
    private var fontSize: CGFloat { min(10, max(7.5, rect.width / 11)) }

    /// Show the SF Symbol only in zones tall enough to accommodate it without crowding.
    private var showIcon: Bool { rect.height > 58 && zone.icon != nil }

    // ── Adaptive label colors ─────────────────────────────────────────────────
    // Light mode: warm dark brown — reads as cartographic ink on parchment.
    // Dark mode: soft white — reads as a luminous label on deep canvas.

    private var labelColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(zone.labelOpacity * 0.82)
            : Color(red: 0.25, green: 0.20, blue: 0.15).opacity(zone.labelOpacity * 0.68)
    }

    private var iconColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(zone.labelOpacity * 0.60)
            : Color(red: 0.25, green: 0.20, blue: 0.15).opacity(zone.labelOpacity * 0.50)
    }

    // White glow strength: strong in light mode (lifts label off parchment);
    // gentle in dark mode (label is already contrasting against dark fill).
    private var glowOpacity: Double {
        colorScheme == .dark ? 0.18 : 0.72
    }

    // ── Body ─────────────────────────────────────────────────────────────────

    var body: some View {
        ZStack {
            zoneFill
            zoneLabel
        }
    }

    // ── Fill layer ────────────────────────────────────────────────────────────
    //
    // Visual effects per zone:
    //   1. Top-to-bottom LinearGradient — lighter top (1.45×), darker base (0.62×).
    //      Stronger directionality than before gives each district perceived depth.
    //   2. Color-tinted ambient shadow (radius 18) — zone hue blooms softly into
    //      the canvas, separating adjacent regions without needing hard borders.
    //   3. Neutral elevation shadow (radius 6, softened to 0.22) — lifts zone off
    //      the canvas surface at a weight appropriate for the lighter parchment base.
    //   4. Top-lit gradient stroke (topLeading → bottomTrailing) — inner edge
    //      highlight simulates glancing light from above-left.

    private var zoneFill: some View {
        ZStack {
            // Gradient fill — lighter top, darker bottom
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(
                    LinearGradient(
                        colors: [
                            zone.fill.opacity(zone.fillOpacity * 1.45),
                            zone.fill.opacity(zone.fillOpacity * 0.62)
                        ],
                        startPoint: .top,
                        endPoint:   .bottom
                    )
                )

            // Inner edge highlight — topLeading catches the "light source"
            RoundedRectangle(cornerRadius: cornerRadius)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.02)
                        ],
                        startPoint: .topLeading,
                        endPoint:   .bottomTrailing
                    ),
                    lineWidth: 0.75
                )
        }
        .frame(width: rect.width, height: rect.height)
        // Color bloom — zone hue bleeds softly into the canvas around it
        .shadow(color: zone.fill.opacity(0.20), radius: 18, x: 0, y: 4)
        // Elevation — softened for the lighter parchment base
        .shadow(color: Color.black.opacity(0.22), radius:  6, x: 0, y: 3)
        .position(x: midX, y: midY)
    }

    // ── Label layer ───────────────────────────────────────────────────────────
    //
    // Two-shadow halo technique:
    //   1. Zone-tinted shadow (radius 2, opacity 0.30) — anchors the label to
    //      its region, tying the text color personality to the zone fill.
    //   2. White glow (radius 4) — lifts the label off the zone surface.
    //      Strong in light mode (label on warm fill), gentle in dark mode.
    //
    // Uppercase + medium weight + 1.2 kerning keeps labels cartographic — they
    // orient without competing with ride pins that sit above them in the ZStack.

    private var zoneLabel: some View {
        VStack(spacing: 3) {
            if showIcon, let icon = zone.icon {
                Image(systemName: icon)
                    .font(.system(size: fontSize - 0.5, weight: .semibold))
                    .foregroundStyle(iconColor)
                    .shadow(color: zone.fill.opacity(0.35), radius: 2, x: 0, y: 0)
                    .shadow(color: Color.white.opacity(glowOpacity * 0.85), radius: 3, x: 0, y: 0)
            }
            Text(zone.label.uppercased())
                .font(.system(size: fontSize - 1, weight: .medium, design: .rounded))
                .kerning(1.2)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .foregroundStyle(labelColor)
                // Zone-tinted shadow — ties label color to its district
                .shadow(color: zone.fill.opacity(0.30), radius: 2, x: 0, y: 0)
                // White glow — ensures readability against zone fill
                .shadow(color: Color.white.opacity(glowOpacity), radius: 4, x: 0, y: 0)
                .frame(maxWidth: rect.width - 14)
        }
        .position(x: midX, y: midY)
        .allowsHitTesting(false)
    }
}

// MARK: - Park layout data
// Zone bounds enclose the ParkMapPin positions defined in ParkMapViewModel.embeddedPins.
// Coordinates (x, y, w, h) are normalized 0–1. Do NOT adjust without moving pins.
//
// canvasColor: adaptive warm parchment (light) / deep charcoal (dark) via mapColor().
// accentColor: adaptive warm dark (light) / park-specific bright accent (dark).
// fillOpacity: 0.24–0.26 across all zones — tinted districts, not tiles.

private extension ParkLayout {

    /// Adaptive color helper. Produces warm parchment in light mode and
    /// park-specific deep charcoal in dark mode without external dependencies.
    static func mapColor(
        light: (Double, Double, Double),
        dark:  (Double, Double, Double)
    ) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(red: dark.0,  green: dark.1,  blue: dark.2,  alpha: 1)
                : UIColor(red: light.0, green: light.1, blue: light.2, alpha: 1)
        })
    }

    // ── Magic Kingdom ────────────────────────────────────────────────────────

    static let magicKingdom = ParkLayout(
        parkId:      "magic-kingdom",
        // Light: neutral warm parchment  |  Dark: deep cool-blue charcoal
        canvasColor: mapColor(light: (0.96, 0.94, 0.90), dark: (0.07, 0.08, 0.14)),
        // Light: warm charcoal dots  |  Dark: royal blue accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (0.30, 0.50, 1.00)),
        zones: [
            MapZone(id: "mk-fantasy",   label: "Fantasyland",         icon: "crown.fill",
                    x: 0.24, y: 0.09, w: 0.50, h: 0.28,
                    fill: Color(red: 0.58, green: 0.25, blue: 0.75),
                    fillOpacity: 0.25),
            MapZone(id: "mk-tomorrow",  label: "Tomorrowland",        icon: "sparkles",
                    x: 0.58, y: 0.24, w: 0.34, h: 0.36,
                    fill: Color(red: 0.18, green: 0.42, blue: 0.80),
                    fillOpacity: 0.25),
            MapZone(id: "mk-liberty",   label: "Liberty\nSquare",     icon: nil,
                    x: 0.20, y: 0.37, w: 0.19, h: 0.20,
                    fill: Color(red: 0.65, green: 0.50, blue: 0.22),
                    fillOpacity: 0.24, labelOpacity: 0.50),
            MapZone(id: "mk-frontier",  label: "Frontier-\nland",     icon: "flame.fill",
                    x: 0.07, y: 0.32, w: 0.20, h: 0.28,
                    fill: Color(red: 0.62, green: 0.30, blue: 0.10),
                    fillOpacity: 0.25),
            MapZone(id: "mk-adventure", label: "Adventureland",       icon: "leaf.fill",
                    x: 0.07, y: 0.50, w: 0.23, h: 0.24,
                    fill: Color(red: 0.15, green: 0.50, blue: 0.22),
                    fillOpacity: 0.25),
            MapZone(id: "mk-main",      label: "Main Street\nU.S.A.", icon: nil,
                    x: 0.30, y: 0.71, w: 0.40, h: 0.20,
                    fill: Color(red: 0.62, green: 0.48, blue: 0.28),
                    fillOpacity: 0.24, labelOpacity: 0.42),
        ]
    )

    // ── EPCOT ────────────────────────────────────────────────────────────────

    static let epcot = ParkLayout(
        parkId:      "epcot",
        // Light: cool-tinted parchment  |  Dark: deep navy charcoal
        canvasColor: mapColor(light: (0.93, 0.95, 0.97), dark: (0.05, 0.08, 0.17)),
        // Light: warm charcoal dots  |  Dark: sky blue accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (0.20, 0.70, 1.00)),
        zones: [
            MapZone(id: "ep-discovery",   label: "World\nDiscovery",    icon: "atom",
                    x: 0.50, y: 0.08, w: 0.40, h: 0.30,
                    fill: Color(red: 0.12, green: 0.38, blue: 0.80),
                    fillOpacity: 0.25),
            MapZone(id: "ep-nature",      label: "World\nNature",       icon: "leaf.fill",
                    x: 0.08, y: 0.14, w: 0.34, h: 0.32,
                    fill: Color(red: 0.10, green: 0.52, blue: 0.32),
                    fillOpacity: 0.25),
            MapZone(id: "ep-celebrate",   label: "World\nCelebration",  icon: "sparkles",
                    x: 0.30, y: 0.18, w: 0.26, h: 0.22,
                    fill: Color(red: 0.62, green: 0.42, blue: 0.08),
                    fillOpacity: 0.24),
            MapZone(id: "ep-showcase",    label: "World Showcase",       icon: "globe.europe.africa.fill",
                    x: 0.08, y: 0.62, w: 0.84, h: 0.28,
                    fill: Color(red: 0.38, green: 0.30, blue: 0.20),
                    fillOpacity: 0.24, labelOpacity: 0.42),
            MapZone(id: "ep-frozen",      label: "Norway\n(Frozen)",     icon: "snowflake",
                    x: 0.14, y: 0.65, w: 0.22, h: 0.22,
                    fill: Color(red: 0.20, green: 0.35, blue: 0.75),
                    fillOpacity: 0.26),
            MapZone(id: "ep-ratatouille", label: "France\n(Remy)",       icon: "fork.knife",
                    x: 0.44, y: 0.70, w: 0.22, h: 0.22,
                    fill: Color(red: 0.62, green: 0.18, blue: 0.28),
                    fillOpacity: 0.26),
        ]
    )

    // ── Hollywood Studios ────────────────────────────────────────────────────

    static let hollywoodStudios = ParkLayout(
        parkId:      "hollywood-studios",
        // Light: warm amber parchment  |  Dark: deep warm brown charcoal
        canvasColor: mapColor(light: (0.97, 0.94, 0.88), dark: (0.11, 0.08, 0.05)),
        // Light: warm charcoal dots  |  Dark: amber accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (1.00, 0.55, 0.15)),
        zones: [
            MapZone(id: "hs-hollywood", label: "Hollywood\nBlvd",          icon: "film.fill",
                    x: 0.28, y: 0.10, w: 0.36, h: 0.26,
                    fill: Color(red: 0.72, green: 0.45, blue: 0.12),
                    fillOpacity: 0.25),
            MapZone(id: "hs-sunset",   label: "Sunset\nBoulevard",         icon: "sun.horizon.fill",
                    x: 0.56, y: 0.24, w: 0.36, h: 0.32,
                    fill: Color(red: 0.75, green: 0.28, blue: 0.08),
                    fillOpacity: 0.25),
            MapZone(id: "hs-galaxys",  label: "Star Wars:\nGalaxy's Edge", icon: "star.fill",
                    x: 0.04, y: 0.50, w: 0.44, h: 0.42,
                    fill: Color(red: 0.25, green: 0.10, blue: 0.42),
                    fillOpacity: 0.26),
            MapZone(id: "hs-toystory", label: "Toy Story\nLand",           icon: "figure.play",
                    x: 0.54, y: 0.50, w: 0.40, h: 0.38,
                    fill: Color(red: 0.28, green: 0.55, blue: 0.15),
                    fillOpacity: 0.25),
        ]
    )

    // ── Animal Kingdom ───────────────────────────────────────────────────────

    static let animalKingdom = ParkLayout(
        parkId:      "animal-kingdom",
        // Light: earthy warm parchment  |  Dark: deep olive charcoal
        canvasColor: mapColor(light: (0.95, 0.94, 0.89), dark: (0.06, 0.10, 0.06)),
        // Light: warm charcoal dots  |  Dark: leaf green accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (0.30, 0.75, 0.30)),
        zones: [
            MapZone(id: "ak-africa",    label: "Africa",                    icon: "pawprint.fill",
                    x: 0.08, y: 0.13, w: 0.38, h: 0.30,
                    fill: Color(red: 0.58, green: 0.40, blue: 0.10),
                    fillOpacity: 0.25),
            MapZone(id: "ak-asia",      label: "Asia",                      icon: "mountain.2.fill",
                    x: 0.56, y: 0.18, w: 0.36, h: 0.36,
                    fill: Color(red: 0.52, green: 0.24, blue: 0.10),
                    fillOpacity: 0.25),
            MapZone(id: "ak-discovery", label: "Discovery\nIsland",         icon: "tree.fill",
                    x: 0.32, y: 0.32, w: 0.36, h: 0.28,
                    fill: Color(red: 0.18, green: 0.42, blue: 0.15),
                    fillOpacity: 0.25),
            MapZone(id: "ak-pandora",   label: "Pandora —\nWorld of Avatar", icon: "moon.stars.fill",
                    x: 0.28, y: 0.60, w: 0.46, h: 0.28,
                    fill: Color(red: 0.10, green: 0.28, blue: 0.55),
                    fillOpacity: 0.26),
        ]
    )

    // ── Disneyland ───────────────────────────────────────────────────────────

    static let disneyland = ParkLayout(
        parkId:      "disneyland",
        // Light: neutral warm parchment  |  Dark: deep blue charcoal
        canvasColor: mapColor(light: (0.96, 0.94, 0.90), dark: (0.06, 0.07, 0.14)),
        // Light: warm charcoal dots  |  Dark: soft blue accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (0.35, 0.55, 1.00)),
        zones: [
            MapZone(id: "dl-toontown",  label: "Mickey's\nToontown",        icon: "theatermasks.fill",
                    x: 0.34, y: 0.05, w: 0.34, h: 0.15,
                    fill: Color(red: 0.15, green: 0.58, blue: 0.52),
                    fillOpacity: 0.25),
            MapZone(id: "dl-fantasy",   label: "Fantasyland",                icon: "crown.fill",
                    x: 0.22, y: 0.16, w: 0.48, h: 0.22,
                    fill: Color(red: 0.55, green: 0.25, blue: 0.70),
                    fillOpacity: 0.25),
            MapZone(id: "dl-tomorrow",  label: "Tomorrow-\nland",            icon: "sparkles",
                    x: 0.60, y: 0.34, w: 0.30, h: 0.28,
                    fill: Color(red: 0.18, green: 0.38, blue: 0.78),
                    fillOpacity: 0.25),
            MapZone(id: "dl-frontier",  label: "Frontier-\nland",            icon: "flame.fill",
                    x: 0.05, y: 0.30, w: 0.16, h: 0.24,
                    fill: Color(red: 0.55, green: 0.28, blue: 0.08),
                    fillOpacity: 0.25, labelOpacity: 0.50),
            MapZone(id: "dl-nos",       label: "New Orleans\nSquare",        icon: "music.quarternote.3",
                    x: 0.12, y: 0.38, w: 0.22, h: 0.22,
                    fill: Color(red: 0.42, green: 0.25, blue: 0.08),
                    fillOpacity: 0.25),
            MapZone(id: "dl-adventure", label: "Adventureland",              icon: "leaf.fill",
                    x: 0.07, y: 0.48, w: 0.22, h: 0.22,
                    fill: Color(red: 0.15, green: 0.45, blue: 0.18),
                    fillOpacity: 0.25),
            MapZone(id: "dl-galaxys",   label: "Star Wars:\nGalaxy's Edge",  icon: "star.fill",
                    x: 0.04, y: 0.60, w: 0.26, h: 0.26,
                    fill: Color(red: 0.22, green: 0.08, blue: 0.38),
                    fillOpacity: 0.26),
            MapZone(id: "dl-main",      label: "Main Street\nU.S.A.",        icon: nil,
                    x: 0.28, y: 0.72, w: 0.44, h: 0.20,
                    fill: Color(red: 0.58, green: 0.44, blue: 0.25),
                    fillOpacity: 0.24, labelOpacity: 0.42),
        ]
    )

    // ── California Adventure ─────────────────────────────────────────────────

    static let californiaAdventure = ParkLayout(
        parkId:      "california-adventure",
        // Light: warm amber parchment  |  Dark: deep warm brown charcoal
        canvasColor: mapColor(light: (0.97, 0.94, 0.89), dark: (0.09, 0.07, 0.05)),
        // Light: warm charcoal dots  |  Dark: warm orange accent
        accentColor: mapColor(light: (0.25, 0.20, 0.15), dark: (1.00, 0.60, 0.20)),
        zones: [
            MapZone(id: "dca-avengers",  label: "Avengers\nCampus",         icon: "shield.fill",
                    x: 0.54, y: 0.08, w: 0.38, h: 0.28,
                    fill: Color(red: 0.72, green: 0.10, blue: 0.12),
                    fillOpacity: 0.26),
            MapZone(id: "dca-hollywood", label: "Hollywood\nLand",          icon: "film.fill",
                    x: 0.26, y: 0.08, w: 0.30, h: 0.22,
                    fill: Color(red: 0.62, green: 0.22, blue: 0.25),
                    fillOpacity: 0.25),
            MapZone(id: "dca-grizzly",   label: "Grizzly\nPeak",            icon: "mountain.2.fill",
                    x: 0.18, y: 0.26, w: 0.34, h: 0.30,
                    fill: Color(red: 0.30, green: 0.35, blue: 0.38),
                    fillOpacity: 0.25),
            MapZone(id: "dca-cars",      label: "Cars Land",                 icon: "car.fill",
                    x: 0.58, y: 0.32, w: 0.36, h: 0.38,
                    fill: Color(red: 0.65, green: 0.28, blue: 0.08),
                    fillOpacity: 0.26),
            MapZone(id: "dca-wharf",     label: "Pacific\nWharf",           icon: "water.waves",
                    x: 0.22, y: 0.52, w: 0.28, h: 0.18,
                    fill: Color(red: 0.18, green: 0.30, blue: 0.45),
                    fillOpacity: 0.24, labelOpacity: 0.50),
            MapZone(id: "dca-pixar",     label: "Pixar Pier",                icon: "sparkles",
                    x: 0.32, y: 0.62, w: 0.58, h: 0.28,
                    fill: Color(red: 0.58, green: 0.22, blue: 0.50),
                    fillOpacity: 0.25),
        ]
    )
}

// MARK: - Previews

#Preview("Magic Kingdom") {
    let comp = ParkCompositionRegistry.composition(for: "magic-kingdom")
    ParkMapBackgroundView(composition: comp)
        .environment(ParkMapViewModel(parkId: "magic-kingdom"))
        .frame(width: comp.contentSize.width, height: comp.contentSize.height)
        .scaleEffect(0.38)   // approx fitScale for a 390-pt-wide preview
}

#Preview("All Parks") {
    ScrollView(.horizontal, showsIndicators: false) {
        HStack(spacing: 2) {
            ForEach([
                "magic-kingdom", "epcot", "hollywood-studios",
                "animal-kingdom", "disneyland", "california-adventure"
            ], id: \.self) { parkId in
                let comp = ParkCompositionRegistry.composition(for: parkId)
                ParkMapBackgroundView(composition: comp)
                    .environment(ParkMapViewModel(parkId: parkId))
                    .frame(width: comp.contentSize.width, height: comp.contentSize.height)
                    .scaleEffect(200 / comp.contentSize.width)
                    .frame(width: 200, height: 380)
                    .clipped()
            }
        }
        .padding(2)
    }
    .background(Color.black)
}
