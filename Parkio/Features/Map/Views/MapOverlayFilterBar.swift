// MapOverlayFilterBar.swift — Floating filter chip bar for the park map.
//
// Three toggle chips in one row:
//   "Show Ridden"   → mapVM.filters.showRidden   (false = hide ridden rides)
//   "Hide Closed"   → mapVM.filters.hideClosed   (true  = hide non-rideable rides)
//   "My Plan Only"  → mapVM.filters.planOnly     (true  = show only planned rides)
//
// Design:
//   • .regularMaterial pill on a fully-rounded RoundedRectangle.
//   • Chips are 32pt tall Capsule buttons, caption semibold.
//   • Selected fill adapts: near-black (light mode) / ghost-white (dark mode),
//     so white label text always passes contrast checks in both appearances.
//   • AppHaptic.selection() fires on every toggle.
//
// Caller contract:
//   Pass mapVM as a plain `let` — @Observable handles read tracking automatically.
//   @Bindable is created locally in body to produce two-way Bindings.
//   Transition is inherited from WaitTimeLegendView.transition for visual unity.

import SwiftUI

// MARK: - MapOverlayFilterBar

struct MapOverlayFilterBar: View {

    /// Plain `let` — @Observable tracks accesses without a property wrapper.
    var mapVM: MapViewModel

    var body: some View {
        // @Bindable converts the @Observable object into a source of Bindings.
        @Bindable var vm = mapVM

        HStack(spacing: 6) {
            FilterChip(label: "Show Ridden",  isOn: $vm.filters.showRidden)
            FilterChip(label: "Hide Closed",  isOn: $vm.filters.hideClosed)
            FilterChip(label: "My Plan Only", isOn: $vm.filters.planOnly)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: AppRadius.full, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.10), radius: 8, x: 0, y: 3)
        .dynamicTypeSize(.large ... .large)
        // Shares the same transition shape as WaitTimeLegendView so the two
        // controls enter and exit as a visual unit.
        .transition(WaitTimeLegendView.transition)
    }
}

// MARK: - FilterChip

private struct FilterChip: View {

    let label: String
    @Binding var isOn: Bool

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            isOn.toggle()
            AppHaptic.selection()
        } label: {
            Text(label)
                .font(.caption.weight(.semibold))
                // White foreground for both selected states (light/dark fills both dark enough).
                .foregroundStyle(isOn ? Color.white : AppColor.textSecondary)
                .padding(.horizontal, 10)
                .frame(height: 32)
                .background(chipFill, in: Capsule())
        }
        .buttonStyle(.plain)
        // Quick cross-fade between selected and unselected fill.
        .animation(AppMotion.quick, value: isOn)
    }

    /// Adaptive selected fill.
    /// Light mode: near-black (contrast ~7:1 with white text).
    /// Dark mode:  ghost-white at 20% opacity on dark material (still passes WCAG AA).
    /// Unselected: near-invisible tint — pill edge provides the only boundary.
    private var chipFill: Color {
        guard isOn else { return Color.primary.opacity(0.07) }
        return colorScheme == .dark
            ? Color.white.opacity(0.20)
            : Color.black.opacity(0.80)
    }
}
