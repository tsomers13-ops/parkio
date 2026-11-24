// DiningServiceFilterBar.swift — All / Quick service / Sit-down chips.
//
// Shared by every screen that lists dining venues. The selection itself
// lives with the screen; this view only draws the control.

import SwiftUI

struct DiningServiceFilterBar: View {

    @Binding var selection: DiningServiceFilter
    var accent: Color

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.xs) {
                ForEach(DiningServiceFilter.allCases) { option in
                    let selected = selection == option
                    Button {
                        withAnimation(AppMotion.quick) { selection = option }
                        AppHaptic.selection()
                    } label: {
                        Text(option.title)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(selected ? .white : AppColor.textSecondary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xxs + 2)
                            .background(
                                selected
                                    ? accent
                                    : AppColor.skeleton.opacity(0.55)
                            )
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier(option.accessibilityIdentifier)
                    .accessibilityLabel(option.accessibilityLabel)
                    .accessibilityAddTraits(selected ? .isSelected : [])
                    .animation(AppMotion.quick, value: selected)
                }
            }
        }
        .accessibilityIdentifier("parkio.dining.serviceFilter")
    }
}
