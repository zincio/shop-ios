import SwiftUI

/// Ordering applied to search results. Defaults to cheapest-first so the top row
/// is the best deal — the same bias the Siri "top match" purchase uses.
enum SortOption: String, CaseIterable, Identifiable {
    case priceLowToHigh = "Price: Low to High"
    case priceHighToLow = "Price: High to Low"
    case relevance = "Relevance"

    var id: String { rawValue }
    var systemImage: String {
        switch self {
        case .priceLowToHigh: return "arrow.up"
        case .priceHighToLow: return "arrow.down"
        case .relevance: return "sparkles"
        }
    }
}

struct HomeView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var query = ""
    @State private var results: [Product] = []
    @State private var isSearching = false
    @State private var errorText: String?
    @State private var selectedProduct: Product?
    @State private var sortOption: SortOption = .priceLowToHigh

    private let zinc = ZincClient()

    /// Results in the raw (relevance) order returned by search, re-sorted per the
    /// selected option. Relevance keeps the search API's own ranking.
    private var sortedResults: [Product] {
        switch sortOption {
        case .relevance:      return results
        case .priceLowToHigh: return results.sorted { $0.priceCents < $1.priceCents }
        case .priceHighToLow: return results.sorted { $0.priceCents > $1.priceCents }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                if let errorText {
                    Text(errorText).foregroundStyle(.red)
                }
                ForEach(sortedResults) { product in
                    Button { selectedProduct = product } label: {
                        ProductRow(product: product)
                    }
                    .buttonStyle(.plain)
                }
                if results.isEmpty && !isSearching { emptyState }
            }
            .navigationTitle("Zinc")
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "What do you need?")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .overlay { if isSearching { ProgressView() } }
            .toolbar {
                if !results.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) { sortMenu }
                }
            }
            .sheet(item: $selectedProduct) { product in
                PurchaseFlowView(product: product, quantity: 1, onOrdered: clearSearch)
            }
        }
    }

    private var sortMenu: some View {
        Menu {
            Picker("Sort", selection: $sortOption) {
                ForEach(SortOption.allCases) { option in
                    Label(option.rawValue, systemImage: option.systemImage).tag(option)
                }
            }
        } label: {
            Label("Sort", systemImage: "arrow.up.arrow.down")
        }
    }

    @ViewBuilder private var emptyState: some View {
        if store.recentSearches.isEmpty {
            ContentUnavailableView(
                "Search to shop",
                systemImage: "magnifyingglass",
                description: Text("Try “toilet paper”, then tap to buy with Apple Pay.")
            )
        } else {
            Section("Recent Searches") {
                ForEach(store.recentSearches, id: \.self) { term in
                    Button {
                        query = term
                        Task { await runSearch() }
                    } label: {
                        Label(term, systemImage: "clock.arrow.circlepath")
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { store.recentSearches.remove(atOffsets: $0) }
            }
        }
    }

    private func clearSearch() {
        query = ""
        results = []
        errorText = nil
    }

    private func runSearch() async {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isSearching = true; errorText = nil
        defer { isSearching = false }
        do {
            // Foreground search can pay the MPP $0.01 challenge with Apple Pay
            // when no Bearer key is set. (Keyed search ignores this closure.)
            results = try await zinc.search(query) { challenges in
                guard let stripe = challenges.first(where: { $0.method == "stripe" }) else {
                    throw PaymentError.noStripeRail
                }
                return try await ApplePayService().pay(challenge: stripe,
                                                       productTitle: "Zinc product search")
            }
            store.addRecentSearch(query)
        } catch {
            errorText = error.localizedDescription
        }
    }
}

struct ProductRow: View {
    let product: Product
    var body: some View {
        HStack(spacing: 12) {
            thumbnail
            VStack(alignment: .leading, spacing: 3) {
                Text(product.title).lineLimit(2)
                if product.brand != nil || product.stars != nil {
                    HStack(spacing: 6) {
                        if let stars = product.stars { ratingView(stars) }
                        if let brand = product.brand {
                            Text(brand).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                        }
                    }
                }
                HStack(spacing: 6) {
                    Text(product.priceFormatted)
                        .font(.subheadline.bold()).foregroundStyle(.tint)
                    Text("·").foregroundStyle(.tertiary)
                    Text(product.retailer.capitalized)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
        }
    }

    @ViewBuilder private func ratingView(_ stars: Double) -> some View {
        HStack(spacing: 2) {
            Image(systemName: "star.fill").font(.caption2).foregroundStyle(.yellow)
            Text(stars.formatted(.number.precision(.fractionLength(1))))
                .font(.caption).foregroundStyle(.secondary)
            if let n = product.numReviews {
                Text("(\(n.formatted(.number.notation(.compactName))))")
                    .font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }

    @ViewBuilder private var thumbnail: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(.quaternary)
            .frame(width: 56, height: 56)
            .overlay {
                if let url = product.imageURL {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit().padding(4)
                        case .failure:
                            Image(systemName: "shippingbox.fill").foregroundStyle(.secondary)
                        default:
                            ProgressView()
                        }
                    }
                } else {
                    Image(systemName: "shippingbox.fill").foregroundStyle(.secondary)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
