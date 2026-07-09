import SwiftUI

/// Ordering applied to search results. Defaults to cheapest-first so the top row
/// is the best deal — the same bias the Siri "top match" purchase uses.
enum SortOption: String, CaseIterable, Identifiable {
    case priceLowToHigh = "Price: Low to High"
    case priceHighToLow = "Price: High to Low"
    case relevance = "Relevance"

    var id: String { rawValue }

    /// Compact label for the chip row (the full `rawValue` is verbose there).
    var chipTitle: String {
        switch self {
        case .priceLowToHigh: return "Lowest Price"
        case .priceHighToLow: return "Highest Price"
        case .relevance:      return "Relevance"
        }
    }

    var systemImage: String {
        switch self {
        case .priceLowToHigh: return "arrow.up"
        case .priceHighToLow: return "arrow.down"
        case .relevance:      return "sparkles"
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
    /// The query whose (possibly empty) results are currently on screen, set once a
    /// search completes successfully. Lets the empty state say "No results for X"
    /// instead of falling back to the blank-slate prompt.
    @State private var lastSearchedQuery: String?

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
                    searchErrorView(errorText)
                }
                ForEach(sortedResults) { product in
                    Button { selectedProduct = product } label: {
                        ProductRow(product: product)
                    }
                    .buttonStyle(.plain)
                }
                if results.isEmpty && !isSearching && errorText == nil { emptyState }
            }
            .navigationTitle("Zinc")
            .searchable(text: $query,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "What do you need?")
            .onSubmit(of: .search) { Task { await runSearch() } }
            .overlay { if isSearching { ProgressView() } }
            // Persistent filter/sort row pinned just below the search bar. Kept as
            // its own scrollable chip bar so more filters (retailer, rating,
            // Prime, etc.) can be added alongside sort later.
            .safeAreaInset(edge: .top, spacing: 0) {
                if !results.isEmpty { filterBar }
            }
            .sheet(item: $selectedProduct) { product in
                PurchaseFlowView(product: product, quantity: 1, onOrdered: clearSearch)
            }
        }
        // A Siri/Apple Intelligence search (SearchProductsIntent) lands here.
        .task { consumePendingSearch() }
        .onChange(of: store.pendingSearch) { _, _ in consumePendingSearch() }
    }

    /// Run a search term handed over by the Siri search intent, then clear it so
    /// it fires exactly once.
    private func consumePendingSearch() {
        guard let term = store.pendingSearch?.trimmingCharacters(in: .whitespaces),
              !term.isEmpty else { return }
        store.pendingSearch = nil
        // Clear any prior results so the incoming Siri search starts from a blank
        // table rather than briefly showing the last query's rows.
        results = []
        errorText = nil
        lastSearchedQuery = nil
        query = term
        Task { await runSearch() }
    }

    private var filterBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SortOption.allCases) { option in
                    sortChip(option)
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
        .background(.bar)
        .overlay(alignment: .bottom) { Divider() }
    }

    private func sortChip(_ option: SortOption) -> some View {
        let selected = option == sortOption
        return Button {
            sortOption = option
        } label: {
            Label(option.chipTitle, systemImage: option.systemImage)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(selected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary),
                            in: Capsule())
                .foregroundStyle(selected ? Color.white : .primary)
        }
        .buttonStyle(.plain)
        .animation(.snappy(duration: 0.15), value: selected)
    }

    @ViewBuilder private var emptyState: some View {
        if let lastSearchedQuery {
            ContentUnavailableView(
                "No results for “\(lastSearchedQuery)”",
                systemImage: "magnifyingglass",
                description: Text("Try a different search term.")
            )
        } else if store.recentSearches.isEmpty {
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
                            // Fill the row and claim its whole area so a tap
                            // anywhere on the row (not just the text) re-runs it.
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                .onDelete { store.recentSearches.remove(atOffsets: $0) }
            }
        }
    }

    /// Error card shown in place of results when a search throws, with a Retry
    /// button that re-runs the current query.
    private func searchErrorView(_ message: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.largeTitle)
                .foregroundStyle(.orange)
            Text("Search failed").font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button { Task { await runSearch() } } label: {
                Label("Retry", systemImage: "arrow.clockwise")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical)
        .listRowSeparator(.hidden)
    }

    private func clearSearch() {
        query = ""
        results = []
        errorText = nil
        lastSearchedQuery = nil
    }

    private func runSearch() async {
        let term = query.trimmingCharacters(in: .whitespaces)
        guard !term.isEmpty else { return }
        isSearching = true; errorText = nil
        defer { isSearching = false }
        do {
            results = try await zinc.search(query)
            lastSearchedQuery = term
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
