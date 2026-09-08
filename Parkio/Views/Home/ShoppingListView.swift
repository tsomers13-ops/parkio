// ShoppingListView.swift — Priority 5B minimal Shopping discovery surface.
//
// Why a new screen rather than folding into AttractionsListView:
//   AttractionsListView is built on SwiftData `Ride` query results
//   (RideMasterData.typeByStableID[ride.id] lookups) — Shopping is
//   deliberately NOT seeded into SwiftData (no "visited this shop" concept),
//   so it has no `Ride` row to join against there. Forcing it in would mean
//   either fabricating fake Ride rows for shops (reintroducing exactly the
//   "visited" semantics Priority 5 was designed to avoid) or bolting a
//   second, incompatible data path onto that view. Per the Priority 5B
//   brief, this view is option 2 (a lightweight new screen reading
//   ShopMasterData directly) rather than option 1 (no clean filter/tab
//   integration exists) or option 3 (jamming into AttractionsListView).
//
// Data: reads ShopMasterData.all directly — no SwiftData, no view model,
// no network. Pushed via NavigationStack's .navigationDestination(isPresented:)
// from HomeView, matching AttractionsListView's own convention. Does NOT
// wrap in its own NavigationStack.
//
// Explicitly out of scope here (unchanged from Priority 5 / 5B):
//   • No wait times, no "visited" tracking, no Best Next Ride participation.
//   • No recommendation scoring — sorting is name/land/tier only.
//   • No Guest Services — this screen is Shopping-only.

import SwiftUI

struct ShoppingListView: View {
    let park: Park

    @State private var searchText = ""
    @State private var selectedCategory: ShoppingCategory?
    @State private var selectedShop: MasterShop?

    private var shopsForPark: [MasterShop] {
        ShopMasterData.shops(for: park)
    }

    private var filteredShops: [MasterShop] {
        var shops = shopsForPark
        if let category = selectedCategory {
            shops = shops.filter { $0.category == category }
        }
        if !searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            let needle = searchText.lowercased()
            shops = shops.filter {
                $0.name.lowercased().contains(needle) || $0.land.lowercased().contains(needle)
            }
        }
        // Destination-tier shops surface first (mirrors the "notable first"
        // convention used elsewhere), then alphabetical by land, then name.
        return shops.sorted {
            if $0.tier != $1.tier { return $0.tier.sortRank > $1.tier.sortRank }
            if $0.land != $1.land { return $0.land < $1.land }
            return $0.name < $1.name
        }
    }

    private var shopsByLand: [(land: String, shops: [MasterShop])] {
        let grouped = Dictionary(grouping: filteredShops, by: \.land)
        return park.lands.compactMap { land in
            guard let shops = grouped[land], !shops.isEmpty else { return nil }
            return (land, shops)
        }
    }

    var body: some View {
        List {
            if filteredShops.isEmpty {
                ContentUnavailableView(
                    "No Shops Found",
                    systemImage: "bag",
                    description: Text(searchText.isEmpty
                        ? "No Shopping is catalogued for \(park.displayName) yet."
                        : "No shops match \"\(searchText)\".")
                )
                .listRowSeparator(.hidden)
            } else {
                ForEach(shopsByLand, id: \.land) { section in
                    Section(section.land) {
                        ForEach(section.shops) { shop in
                            Button {
                                selectedShop = shop
                            } label: {
                                ShoppingRow(shop: shop)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Search shops or lands")
        .navigationTitle("Shopping")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("All Categories") { selectedCategory = nil }
                    Divider()
                    ForEach(ShoppingCategory.allCases, id: \.self) { category in
                        Button(category.label) { selectedCategory = category }
                    }
                } label: {
                    Label("Filter", systemImage: selectedCategory == nil
                        ? "line.3.horizontal.decrease.circle"
                        : "line.3.horizontal.decrease.circle.fill")
                }
            }
        }
        .sheet(item: $selectedShop) { shop in
            ShoppingDetailSheet(shop: shop)
                .presentationDetents([.medium, .large])
        }
    }
}

// MARK: - Row

private struct ShoppingRow: View {
    let shop: MasterShop

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "bag.fill")
                .foregroundStyle(shop.category.tintColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(shop.name)
                    .font(.body.weight(.medium))
                    .foregroundStyle(AppColor.textPrimary)
                Text(shop.category.label)
                    .font(.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }

            Spacer()

            if shop.tier != .standard {
                Text(shop.tier.label)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(shop.tier.badgeColor.opacity(0.15))
                    .foregroundStyle(shop.tier.badgeColor)
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Detail sheet

private struct ShoppingDetailSheet: View {
    let shop: MasterShop
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(shop.name)
                            .font(.title3.bold())
                        Text("\(shop.land) · \(shop.park.displayName)")
                            .font(.subheadline)
                            .foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.vertical, 4)
                }

                Section("Details") {
                    LabeledContent("Category", value: shop.category.label)
                    LabeledContent("Tier", value: shop.tier.label)
                }

                if let editorial = shop.editorial {
                    if let notableFor = editorial.notableFor {
                        Section("Why It's Notable") {
                            Text(notableFor)
                        }
                    }
                    if !editorial.merchandiseFocus.isEmpty {
                        Section("Merchandise Focus") {
                            ForEach(editorial.merchandiseFocus, id: \.self) { item in
                                Text(item)
                            }
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Display helpers (view-layer only; no effect on the ShopMasterData model)
//
// ShoppingCategory already defines `.label` in ShopMasterData.swift — not
// redeclared here. ShoppingTier has no display label yet (it's a pure
// signal type in the model layer), so that one small addition lives here,
// at the view layer, rather than growing the model for UI-only text.

private extension ShoppingTier {
    var sortRank: Int {
        switch self {
        case .destination: return 2
        case .notable:      return 1
        case .standard:     return 0
        }
    }

    var label: String {
        switch self {
        case .standard:    return "Standard"
        case .notable:     return "Notable"
        case .destination: return "Destination"
        }
    }

    var badgeColor: Color {
        switch self {
        case .standard:    return .gray
        case .notable:     return .blue
        case .destination: return .purple
        }
    }
}

private extension ShoppingCategory {
    var tintColor: Color {
        switch self {
        case .generalMerchandise:    return .blue
        case .specialty:             return .purple
        case .attractionMerchandise: return .orange
        case .foodConfectionery:     return .pink
        }
    }
}

// MasterShop has no natural SwiftData/Ride identity (it isn't seeded) —
// stableID is already a unique per-shop string, so it's the obvious Identifiable
// key. Internal (not public), matching this target's access-level convention.
extension MasterShop: Identifiable {
    var id: String { stableID }
}
