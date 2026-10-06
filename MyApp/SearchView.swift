import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Search tab: a search field, brands to explore by category, and shopping hotspots nearby.
struct SearchView: View {
    @State private var query = ""
    /// Selected category chip; empty means "See all".
    @State private var category = SearchData.categories[0]
    @State private var hint = 0
    @FocusState private var searching: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var brands: [SearchBrand] {
        if query.isEmpty {
            return category.isEmpty ? SearchData.brands : SearchData.brands.filter { $0.categories.contains(category) }
        }
        return SearchData.brands.filter { $0.name.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                header
                Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)

                VStack(alignment: .leading, spacing: R.spacingSpace32) {
                    if query.isEmpty {
                        categoriesBlock
                        hotspots
                    } else {
                        results
                    }
                }
                .padding(.top, R.spacingSpace24)
                .padding(.bottom, R.spacingSpace48)
            }
        }
        .scrollIndicators(.hidden)
        .scrollDismissesKeyboard(.immediately)
        .background(alignment: .top) { DistrictGlow() }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .task {
            // Cycle the brand named in the search hint.
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.35)) {
                    hint = (hint + 1) % SearchData.brands.count
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: query.isEmpty)
    }

    // MARK: Header

    private var header: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Search")
                .backstageText(.title2)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)

            HStack(spacing: R.spacingSpace12) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(M.iconSecondary)
                ZStack(alignment: .leading) {
                    if query.isEmpty {
                        Text("Search for '\(SearchData.brands[hint].name)'")
                            .backstageText(.body3)
                            .foregroundStyle(M.textTertiary)
                            .lineLimit(1)
                            .id(hint)
                            .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity),
                                                    removal: .move(edge: .top).combined(with: .opacity)))
                            .accessibilityHidden(true)
                    }
                    TextField("", text: $query)
                        .backstageText(.body3)
                        .foregroundStyle(M.textPrimary)
                        .focused($searching)
                        .submitLabel(.search)
                        .accessibilityLabel("Search brands")
                }
                .clipped()
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundStyle(M.iconTertiary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Clear search")
                }
            }
            .padding(.leading, R.spacingSpace16)
            .padding(.trailing, query.isEmpty ? R.spacingSpace16 : R.spacingSpace4)
            .frame(height: 44)
            .background(M.surfacePrimary.opacity(0.6), in: Capsule())
            .overlay(Capsule().strokeBorder(searching ? M.borderSelection : M.borderModerate, lineWidth: R.stroke1Px))
            .contentShape(Capsule())
            .onTapGesture { searching = true }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace8)
        .padding(.bottom, R.spacingSpace16)
    }

    // MARK: Categories

    private var categoriesBlock: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(alignment: .firstTextBaseline) {
                Text("Explore by categories")
                    .backstageText(.label1)
                    .foregroundStyle(M.textSecondary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { withAnimation(.snappy) { category = "" } } label: {
                    Text("See all")
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                        .overlay(alignment: .bottom) {
                            Line()
                                .stroke(M.textPrimary, style: StrokeStyle(lineWidth: R.stroke1Px, dash: [3, 2]))
                                .frame(height: R.stroke1Px)
                                .offset(y: 4)
                        }
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, R.spacingSpace16)

            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(SearchData.categories, id: \.self) { c in
                        Button {
                            withAnimation(.snappy) { category = c }
                        } label: { Text(c) }
                        .buttonStyle(BackstageFilterButtonStyle(isActive: c == category))
                        .accessibilityAddTraits(c == category ? .isSelected : [])
                    }
                }
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)

            brandGrid(brands)
                .id(category)
                .transition(.opacity)
        }
    }

    /// Two rows of brands that scroll sideways together.
    private func brandGrid(_ list: [SearchBrand]) -> some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.fixed(BrandTile.height), spacing: R.spacingSpace20),
                             GridItem(.fixed(BrandTile.height))],
                      alignment: .top, spacing: R.spacingSpace12) {
                ForEach(list) { BrandTile(brand: $0) }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: Hotspots

    private var hotspots: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text("Popular shopping hotspots near you")
                .backstageText(.label1)
                .foregroundStyle(M.textSecondary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)

            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace12) {
                    ForEach(SearchData.hotspots, id: \.name) { spot in
                        VStack(spacing: R.spacingSpace4) {
                            Text(spot.name)
                                .backstageText(.title4)
                                .foregroundStyle(M.textPrimary)
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                            Text(spot.distance)
                                .backstageText(.body3)
                                .foregroundStyle(M.textSecondary)
                        }
                        .padding(R.spacingSpace12)
                        .frame(width: 140, height: 88)
                        .background(
                            LinearGradient(colors: [M.brandPurple900, M.surfacePrimary],
                                           startPoint: .top, endPoint: .bottom),
                            in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16)
                        )
                        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                        .accessibilityElement(children: .combine)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }

    // MARK: Results

    private var results: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text(brands.isEmpty ? "No brands match '\(query)'" : "Brands")
                .backstageText(.label1)
                .foregroundStyle(M.textSecondary)
                .padding(.horizontal, R.spacingSpace16)
            if !brands.isEmpty {
                brandGrid(brands)
            }
        }
    }
}

/// A brand: photo with its square logo tucked over the corner, then name and offer.
struct BrandTile: View {
    let brand: SearchBrand
    static let height: CGFloat = 138

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            ArtView(art: Art(brand.photo, [0x333333, 0x666666]))
                .frame(width: 86, height: 86)
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                .overlay(alignment: .bottomTrailing) {
                    BrandMark(brand: brand.name, mark: brand.mark, size: 38)
                        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8).strokeBorder(M.backgroundPrimary, lineWidth: R.stroke2Px))
                        .offset(x: 6, y: 8)
                }
                .padding(.bottom, R.spacingSpace8)
            VStack(alignment: .leading, spacing: 2) {
                Text(brand.name)
                    .backstageText(.body3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text(brand.offer)
                    .backstageText(.body3)
                    .foregroundStyle(M.textOffer)
                    .lineLimit(1)
            }
        }
        .frame(width: 94, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(brand.name), \(brand.offer)")
    }
}

/// A horizontal line, for the dotted "See all" underline.
private struct Line: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.minX, y: rect.midY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        }
    }
}

// MARK: - Data

struct SearchBrand: Identifiable {
    var id: String { name }
    let name: String
    let mark: String
    let photo: String
    /// Offer line. Placeholder copy until live offers are wired in.
    let offer: String
    let categories: Set<String>
}

enum SearchData {
    static let categories = ["Apparel", "Footwear", "Accessories", "Salon & Wellness"]

    static let brands: [SearchBrand] = [
        SearchBrand(name: "H&M", mark: "H&M", photo: "rack_hm_overcoat", offer: "Bank benefits", categories: ["Apparel"]),
        SearchBrand(name: "Zara", mark: "ZARA", photo: "rack_zara_dress", offer: "New season in", categories: ["Apparel", "Accessories"]),
        SearchBrand(name: "Nicobar", mark: "NICO\nBAR", photo: "rack_nicobar_kaftan", offer: "15% off above ₹4,999", categories: ["Apparel", "Accessories"]),
        SearchBrand(name: "Snitch", mark: "SNI\nTCH", photo: "rack_snitch_biker", offer: "Bank benefits", categories: ["Apparel"]),
        SearchBrand(name: "The Souled Store", mark: "TSS", photo: "rack_tss_tee", offer: "Bank benefits", categories: ["Apparel"]),
        SearchBrand(name: "Bonkers Corner", mark: "BNKR", photo: "rack_bonkers_patchwork", offer: "Up to 40% off", categories: ["Apparel"]),
        SearchBrand(name: "Doodlage", mark: "DOOD\nLAGE", photo: "story_doodlage", offer: "Flat ₹500 off", categories: ["Apparel"]),
        SearchBrand(name: "Cord", mark: "CORD", photo: "story_cord", offer: "Bank benefits", categories: ["Apparel", "Accessories"]),
        SearchBrand(name: "Blu", mark: "blu", photo: "rack_blu_pinafore", offer: "Up to 50% off", categories: ["Apparel"]),
        SearchBrand(name: "adidas", mark: "adidas", photo: "rack_adidas_popper", offer: "Up to 30% off", categories: ["Apparel", "Footwear"]),
        SearchBrand(name: "Gully Labs", mark: "गली\nLABS", photo: "story_gully_labs", offer: "Bank benefits", categories: ["Footwear"]),
        SearchBrand(name: "Nappa Dori", mark: "ND", photo: "story_nappa_dori", offer: "10% off above ₹9,999", categories: ["Accessories"]),
        SearchBrand(name: "Project Qaafi", mark: "qaafi", photo: "story_qaafi", offer: "Bank benefits", categories: ["Salon & Wellness"]),
    ]

    /// Placeholder distances until location is wired in.
    static let hotspots: [(name: String, distance: String)] = [
        ("Cyberhub\nDLF Phase 2", "2 km"),
        ("Ambience\nMall", "3 km"),
        ("Galleria\nMarket", "4 km"),
        ("Sector 29", "5 km"),
    ]
}

#Preview {
    SearchView().preferredColorScheme(.dark)
}
