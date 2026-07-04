// MapCalibrationView.swift — Live drag-to-calibrate overlay for the map canvas.
//
// Shown when ParkMapViewModel.debugMode == true.
// Replaces the normal PinsLayerView so calibration handles and regular
// markers don't overlap.
//
// Interactions:
//   • Drag a handle  → moves pin, shows crosshair + (x, y) readout
//   • Tap a handle   → selects it, shows detail panel at bottom
//   • Undo button    → restores pin to position before last drag
//   • Snap toggle    → locks positions to 0.01 grid
//   • Apply button   → writes positions back to ParkMapViewModel
//   • Copy Swift     → copies pasteable pin() calls to clipboard
//
// Note: All sub-views are extracted as separate structs to keep each
// @ViewBuilder body simple and avoid "Failed to produce diagnostic" crashes.

import SwiftUI

// MARK: - Root overlay

struct MapCalibrationView: View {
    @Environment(CalibrationViewModel.self) private var calVM
    @Environment(ParkMapViewModel.self)     private var parkMapVM

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                ForEach(calVM.pins) { pin in
                    CalibrationHandle(pinId: pin.internalRideId, canvasSize: geo.size)
                }
                DragReadoutView(canvasSize: geo.size)
            }
            .overlay(alignment: .top)    { CalibrationToolbar(parkMapVM: parkMapVM) }
            .overlay(alignment: .bottom) { SelectedPinPanel() }
        }
    }
}

// MARK: - Drag readout (crosshair + live coordinates)

/// Shown while a pin is being dragged.
/// Extracted as a struct so the conditional body stays a single expression.
private struct DragReadoutView: View {
    let canvasSize: CGSize
    @Environment(CalibrationViewModel.self) private var calVM

    var body: some View {
        if calVM.draggingPinId != nil {
            CrosshairOverlay(
                normX:      calVM.dragLiveX,
                normY:      calVM.dragLiveY,
                canvasSize: canvasSize
            )
        }
    }
}

private struct CrosshairOverlay: View {
    let normX: Double
    let normY: Double
    let canvasSize: CGSize

    private var screenX: CGFloat { normX * canvasSize.width }
    private var screenY: CGFloat { normY * canvasSize.height }
    private var badgeLeft: Bool  { normX > 0.65 }
    private var badgeAbove: Bool { normY > 0.15 }

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Horizontal rule
            Rectangle()
                .fill(Color.yellow.opacity(0.55))
                .frame(width: canvasSize.width, height: 1)
                .position(x: canvasSize.width / 2, y: screenY)

            // Vertical rule
            Rectangle()
                .fill(Color.yellow.opacity(0.55))
                .frame(width: 1, height: canvasSize.height)
                .position(x: screenX, y: canvasSize.height / 2)

            // Coordinate badge
            Text(String(format: "%.3f, %.3f", normX, normY))
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(.black)
                .padding(.horizontal, 7)
                .padding(.vertical, 4)
                .background(Color.yellow, in: RoundedRectangle(cornerRadius: 5))
                .shadow(color: .black.opacity(0.3), radius: 2)
                .position(
                    x: badgeLeft  ? screenX - 58 : screenX + 58,
                    y: badgeAbove ? screenY - 22 : screenY + 22
                )
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Top toolbar

private struct CalibrationToolbar: View {
    let parkMapVM: ParkMapViewModel
    @Environment(CalibrationViewModel.self) private var calVM
    @State private var showCopied      = false
    @State private var showCopiedJSON  = false
    @State private var showResetAlert  = false

    var body: some View {
        VStack(spacing: 0) {
            // Row 1 — primary actions
            HStack(spacing: 8) {
                CalibToolbarButton(
                    label: "Undo",
                    icon:  "arrow.uturn.backward",
                    tint:  .orange,
                    disabled: !calVM.canUndo
                ) { calVM.undo() }

                CalibToolbarButton(
                    label: calVM.snapToGrid ? "Snap ON" : "Snap OFF",
                    icon:  calVM.snapToGrid ? "grid" : "square.dashed",
                    tint:  calVM.snapToGrid ? .green : .gray
                ) { calVM.snapToGrid.toggle() }

                Spacer()

                CalibToolbarButton(
                    label: "Apply",
                    icon:  "checkmark.circle.fill",
                    tint:  .blue
                ) { calVM.apply(to: parkMapVM) }
            }

            // Row 2 — export + reset
            HStack(spacing: 8) {
                // Reset all: confirm before discarding
                CalibToolbarButton(
                    label: "Reset All",
                    icon:  "arrow.counterclockwise",
                    tint:  .red
                ) { showResetAlert = true }
                .confirmationDialog("Discard all unsaved changes?",
                                    isPresented: $showResetAlert,
                                    titleVisibility: .visible) {
                    Button("Reset All", role: .destructive) {
                        calVM.resetAll(from: parkMapVM)
                    }
                }

                Spacer()

                CalibToolbarButton(
                    label: showCopied ? "Copied!" : "Swift",
                    icon:  showCopied ? "checkmark" : "swift",
                    tint:  showCopied ? .green : .purple
                ) {
                    UIPasteboard.general.string = calVM.exportAsSwift()
                    withAnimation { showCopied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopied = false }
                    }
                }

                CalibToolbarButton(
                    label: showCopiedJSON ? "Copied!" : "JSON",
                    icon:  showCopiedJSON ? "checkmark" : "doc.badge.arrow.up",
                    tint:  showCopiedJSON ? .green : .cyan
                ) {
                    UIPasteboard.general.string = calVM.exportAsJSON()
                    withAnimation { showCopiedJSON = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        withAnimation { showCopiedJSON = false }
                    }
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.ultraThinMaterial)
    }
}

private struct CalibToolbarButton: View {
    let label: String
    let icon: String
    let tint: Color
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(label, systemImage: icon)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(tint.opacity(0.18), in: RoundedRectangle(cornerRadius: 7))
                .foregroundStyle(tint)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.4 : 1.0)
    }
}

// MARK: - Bottom panel (selected pin detail)

private struct SelectedPinPanel: View {
    @Environment(CalibrationViewModel.self) private var calVM

    var body: some View {
        if let pin = calVM.selectedPin {
            PinDetailCard(pin: pin)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .animation(.spring(response: 0.3), value: calVM.selectedPinId)
        }
    }
}

private struct PinDetailCard: View {
    let pin: ParkMapPin
    @Environment(CalibrationViewModel.self) private var calVM

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(pin.internalRideId)
                        .font(.system(size: 12, weight: .bold, design: .monospaced))
                        .foregroundStyle(.primary)
                    Text(pin.displayName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(String(format: "x: %.3f\ny: %.3f", pin.mapX, pin.mapY))
                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.yellow)
                    .multilineTextAlignment(.trailing)

                Button { calVM.select(nil) } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.leading, 4)
            }

            HStack(spacing: 16) {
                Label("Priority \(pin.priority)", systemImage: "flag.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Label(pin.anchorType.rawValue, systemImage: "arrow.down.to.line")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                if pin.isOutOfBounds {
                    Label("OUT OF BOUNDS", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: -2)
        .padding(.horizontal, 12)
        .padding(.bottom, 10)
    }
}

// MARK: - Calibration handle (wrapper — resolves optional pin)

/// Looks up the pin live from CalibrationViewModel so position stays
/// in sync as the drag updates. Splits into a wrapper + body struct
/// to keep each @ViewBuilder body simple for the type-checker.
private struct CalibrationHandle: View {
    let pinId: String
    let canvasSize: CGSize
    @Environment(CalibrationViewModel.self) private var calVM

    var body: some View {
        if let pin = calVM.pins.first(where: { $0.internalRideId == pinId }) {
            CalibrationHandleBody(
                pin:        pin,
                canvasSize: canvasSize,
                isSelected: calVM.selectedPinId == pinId,
                isDragging: calVM.draggingPinId == pinId,
                onDragChanged: { translation in
                    if calVM.draggingPinId != pinId { calVM.beginDrag(pinId: pinId) }
                    calVM.updateDrag(translation: translation, canvasSize: canvasSize)
                },
                onDragEnded:   { calVM.endDrag() },
                onTap:         { calVM.select(pinId) }
            )
        }
    }
}

private struct CalibrationHandleBody: View {
    let pin:        ParkMapPin
    let canvasSize: CGSize
    let isSelected: Bool
    let isDragging: Bool
    let onDragChanged: (CGSize) -> Void
    let onDragEnded:   () -> Void
    let onTap:         () -> Void

    private var pinX: CGFloat    { pin.canvasPoint(in: canvasSize).x }
    private var pinY: CGFloat    { pin.canvasPoint(in: canvasSize).y }
    private var dotSize: CGFloat { isDragging ? 22 : isSelected ? 17 : 12 }
    private var ringSize: CGFloat{ dotSize + 12 }
    private var dotColor: Color  { isDragging ? .yellow : isSelected ? .orange : .white }
    private var zValue: Double   { isDragging ? 200 : isSelected ? 100 : Double(4 - pin.priority) }

    var body: some View {
        handleGraphic
            .position(x: pinX, y: pinY)
            .zIndex(zValue)
            .animation(.easeInOut(duration: 0.12), value: isSelected)
            .animation(.easeInOut(duration: 0.08), value: isDragging)
            .gesture(
                DragGesture(minimumDistance: 2)
                    .onChanged { v in onDragChanged(v.translation) }
                    .onEnded   { _ in onDragEnded() }
            )
            .onTapGesture { onTap() }
    }

    private var handleGraphic: some View {
        ZStack {
            // Invisible oversized tap target (minimum 44pt)
            Circle()
                .fill(Color.clear)
                .frame(width: 44, height: 44)
                .contentShape(Circle())

            // Selection / drag ring
            if isSelected || isDragging {
                Circle()
                    .strokeBorder(dotColor.opacity(0.45), lineWidth: 2)
                    .frame(width: ringSize, height: ringSize)
            }

            // Pin dot
            Circle()
                .fill(dotColor)
                .frame(width: dotSize, height: dotSize)
                .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)

            // Priority number (hidden while dragging to reduce clutter)
            if !isDragging {
                Text("\(pin.priority)")
                    .font(.system(size: 7, weight: .black))
                    .foregroundStyle(Color.black.opacity(0.65))
            }
        }
    }
}

// MARK: - Preview

#Preview("Calibration — Disneyland") {
    let parkMapVM    = ParkMapViewModel.previewStub(parkId: "disneyland")
    let calibrationVM = CalibrationViewModel()
    calibrationVM.sync(from: parkMapVM)
    parkMapVM.debugMode = true

    return ZStack {
        Color(red: 0.18, green: 0.22, blue: 0.18).ignoresSafeArea()
        MapCalibrationView()
            .environment(calibrationVM)
            .environment(parkMapVM)
    }
}
