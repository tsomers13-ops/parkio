// DiningPriceKey.swift — the four Disney price ranges, in one place.
//
// The dining detail is already a sheet. A second sheet on top of it is what
// used to dismiss the detail (see CommunityRatingForm). From the detail the
// key is pushed. From Home and the dining list it is a sheet, because those
// screens are not themselves sheets.

import SwiftUI

struct DiningPriceKeyButton: View {
    let identifier: String
    /// When the parent presents the key itself (the dining detail pushes it),
    /// pass that binding and do not also present a sheet.
    var isPresented: Binding<Bool>? = nil

    @State private var localPresented = false

    private var presented: Binding<Bool> {
        isPresented ?? $localPresented
    }

    var body: some View {
        if isPresented == nil {
            keyButton.sheet(isPresented: $localPresented) {
                NavigationStack {
                    DiningPriceKeyScreen(showsDone: true)
                }
                .presentationDetents([.medium, .large])
            }
        } else {
            keyButton
        }
    }

    private var keyButton: some View {
        Button {
            presented.wrappedValue = true
        } label: {
            Image(systemName: "info.circle")
                .font(.body)
                .padding(AppSpacing.xs)
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Price key")
        .accessibilityHint("Shows what each price range means")
        .accessibilityIdentifier(identifier)
    }
}

/// Disney's four per-adult ranges. Used by both the sheet and the push.
struct DiningPriceKeyScreen: View {
    var showsDone: Bool = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AppSpacing.lg) {
                ForEach(PriceTier.allCases, id: \.self) { tier in
                    HStack(alignment: .firstTextBaseline, spacing: AppSpacing.md) {
                        Text(tier.displayString)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColor.textPrimary)
                            .frame(minWidth: 64, alignment: .leading)
                        Text(tier.bandText)
                            .font(.body)
                            .foregroundStyle(AppColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel(tier.accessibilityLabel)
                    .accessibilityIdentifier("parkio.dining.priceKey.band.\(tier.rawValue)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(AppSpacing.screenEdge)
        }
        .background(AppColor.background)
        .accessibilityIdentifier("parkio.dining.priceKey.panel")
        .navigationTitle("Price key")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDone {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .accessibilityIdentifier("parkio.dining.priceKey.done")
                }
            }
        }
    }
}
