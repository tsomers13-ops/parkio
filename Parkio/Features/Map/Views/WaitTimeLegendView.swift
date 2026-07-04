// WaitTimeLegendView.swift — Floating wait-time color scale pill for the map canvas.
//
// Layout:
//   • 210pt wide × ~32pt tall pill on .regularMaterial.
//   • 120pt gradient bar (green → amber → red) centered in the pill.
//   • "0", "30", "60+" labels aligned beneath the bar's left, mid, right edges.
//
// Caller contract:
//   • isVisible drives appearance — flip it inside withAnimation.
//   • This view only declares the transition shape; it does not drive timing.
//   • MapOverlayFilterBar reuses Self.transition so both controls move identically.

import SwiftUI

// MARK: - View

struct WaitTimeLegendView: View {

    /// Controls whether the pill is rendered. Animate externally via withAnimation.
    let isVisible: Bool

    var body: some View {
        if isVisible {
            pill
                .transition(Self.transition)
        }
    }

    // MARK: - Pill

    private var pill: some View {
        VStack(spacing: 3) {
            gradientBar
            scaleLabels
        }
        // Fixed width so the pill never shrinks or grows with label changes.
        .frame(width: 210)
        .padding(.vertical, 6)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
        )
        .overlay {
            // 0.5pt stroke lifts the pill edge off all map backgrounds.
            RoundedRectangle(cornerRadius: AppRadius.lg, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        // Prevent Dynamic Type from inflating the pill past its fixed 210pt budget.
        .dynamicTypeSize(.large ... .large)
    }

    // MARK: - Gradient bar

    private var gradientBar: some View {
        LinearGradient(
            stops: [
                .init(color: AppColor.waitColor(minutes: 0),  location: 0.0),
                .init(color: AppColor.waitColor(minutes: 30), location: 0.5),
                .init(color: AppColor.waitColor(minutes: 60), location: 1.0),
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: 120, height: 8)
        .clipShape(Capsule())
        .overlay {
            // Inner border keeps the green end readable on light parchment backgrounds.
            Capsule()
                .strokeBorder(Color.black.opacity(0.10), lineWidth: 0.5)
        }
    }

    // MARK: - Scale labels

    private var scaleLabels: some View {
        // HStack width matches the gradient bar exactly so labels align to its edges.
        HStack(spacing: 0) {
            Text("0")
            Spacer()
            Text("30")
            Spacer()
            Text("60+")
        }
        .font(.system(size: 9, weight: .medium, design: .rounded))
        .foregroundStyle(AppColor.textSecondary)
        .frame(width: 120)
    }

    // MARK: - Shared transition

    /// Shared with MapOverlayFilterBar so legend and filter bar enter/exit identically.
    static let transition: AnyTransition = .move(edge: .bottom)
        .combined(with: .opacity)
        .combined(with: .scale(scale: 0.96, anchor: .bottom))
}

// MARK: - Preview

#Preview("Wait-time legend") {
    ZStack {
        Color(.systemGroupedBackground).ignoresSafeArea()
        WaitTimeLegendView(isVisible: true)
    }
}
