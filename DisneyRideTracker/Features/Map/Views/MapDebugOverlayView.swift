// MapDebugOverlayView.swift — Calibration overlay for ParkMapCanvasView.
//
// Shown only when ParkMapViewModel.debugMode == true.
// Helps map authors tune pin positions against the background image.
//
// Renders:
//   • 10×10 semi-transparent grid with (x, y) labels at every intersection
//   • Crosshair dot at each ParkMapPin's canvasPoint
//   • Label showing internalRideId + raw (mapX, mapY) below the dot
//   • Out-of-bounds pins (mapX/mapY outside 0–1) highlighted in red
//   • Out-of-bounds pins are clamped to the edge before being drawn

import SwiftUI

struct MapDebugOverlayView: View {
    @Environment(ParkMapViewModel.self) private var parkMapVM

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                // Semi-transparent 10×10 grid
                gridCanvas(size: geo.size)

                // Grid coordinate labels at each intersection
                gridLabels(size: geo.size)

                // Pin debug markers
                ForEach(parkMapVM.pins) { pin in
                    pinDebugMarker(pin: pin, size: geo.size)
                }
            }
        }
        .allowsHitTesting(false)    // Debug overlay never consumes touches
    }

    // MARK: - Grid

    private func gridCanvas(size: CGSize) -> some View {
        Canvas { context, canvasSize in
            let steps = 10
            let gridColor = Color.white.opacity(0.22)
            let accentColor = Color.yellow.opacity(0.40)    // 0.5 intervals

            for i in 0...steps {
                let t = Double(i) / Double(steps)
                let x = canvasSize.width  * t
                let y = canvasSize.height * t
                let isMid = (i == 5)
                let color = isMid ? accentColor : gridColor

                var vPath = Path()
                vPath.move(to: CGPoint(x: x, y: 0))
                vPath.addLine(to: CGPoint(x: x, y: canvasSize.height))
                context.stroke(vPath, with: .color(color), lineWidth: isMid ? 1.0 : 0.5)

                var hPath = Path()
                hPath.move(to: CGPoint(x: 0, y: y))
                hPath.addLine(to: CGPoint(x: canvasSize.width, y: y))
                context.stroke(hPath, with: .color(color), lineWidth: isMid ? 1.0 : 0.5)
            }
        }
    }

    private func gridLabels(size: CGSize) -> some View {
        // Render labels at every other intersection to reduce clutter
        ZStack(alignment: .topLeading) {
            ForEach(Array(0...10), id: \.self) { col in
                ForEach(Array(0...10), id: \.self) { row in
                    if (col + row) % 2 == 0 {
                        let x = size.width  * Double(col) / 10.0
                        let y = size.height * Double(row) / 10.0

                        Text(String(format: "%.1f,%.1f",
                                    Double(col) / 10.0,
                                    Double(row) / 10.0))
                            .font(.system(size: 7, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.55))
                            .background(Color.black.opacity(0.30))
                            .position(x: x + 20, y: y + 7)
                    }
                }
            }
        }
    }

    // MARK: - Pin markers

    @ViewBuilder
    private func pinDebugMarker(pin: ParkMapPin, size: CGSize) -> some View {
        let raw = pin.canvasPoint(in: size)
        // Clamp so out-of-bounds pins are still visible at the edge
        let clampedX = min(max(raw.x, 4), size.width  - 4)
        let clampedY = min(max(raw.y, 4), size.height - 4)
        let isOOB    = pin.isOutOfBounds
        let dotColor: Color = isOOB ? .red : .yellow

        ZStack(alignment: .topLeading) {
            // Crosshair dot
            Circle()
                .fill(dotColor.opacity(0.92))
                .frame(width: 7, height: 7)
                .overlay(
                    Circle().strokeBorder(Color.black.opacity(0.6), lineWidth: 0.5)
                )

            // Label card: rideId + coordinates
            VStack(alignment: .leading, spacing: 1) {
                Text(pin.internalRideId)
                    .font(.system(size: 7, weight: .bold, design: .monospaced))
                Text(String(format: "(%.2f, %.2f)", pin.mapX, pin.mapY))
                    .font(.system(size: 6, design: .monospaced))

                if isOOB {
                    Text("OUT OF BOUNDS")
                        .font(.system(size: 6, weight: .black, design: .monospaced))
                        .foregroundStyle(.red)
                }
            }
            .foregroundStyle(dotColor)
            .padding(.horizontal, 4)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.60), in: RoundedRectangle(cornerRadius: 3))
            .offset(x: 6, y: -22)
        }
        .position(x: clampedX, y: clampedY)
    }
}

// MARK: - Preview

#Preview("Debug Overlay — Disneyland") {
    let parkMapVM = ParkMapViewModel.previewStub(parkId: "disneyland")
    parkMapVM.debugMode = true

    return ZStack {
        // Simulate the map background with a simple gradient
        LinearGradient(
            colors: [Color.teal.opacity(0.4), Color.green.opacity(0.3)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()

        MapDebugOverlayView()
            .environment(parkMapVM)
    }
}
