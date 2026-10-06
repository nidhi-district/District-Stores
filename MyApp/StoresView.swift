import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Stores tab: a promo carousel, categories, new-in-store highlights, District benefits, curated
/// collections near you and the full store list. Sizes follow the District Stores screen.
struct StoresView: View {
    @State private var location = "Vatika City"
    @State private var saved: Set<String> = []
    @State private var offerFilter: OfferFilter = .all
    @State private var sort: StoreSort = .distance

    private let locations = ["Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2", "Sector 29"]

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: R.spacingSpace40) {
                PromoBanner(image: "banner_one8_premiere", label: "one8 global premiere, 21st June 2026")
                section("Shop by category") { categories }
                section("What's new in stores") { whatsNew }
                section("District benefits") { benefits }
                section("In your district") { collections }
                section("All stores") { allStores }
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        // The banner starts at the very top, behind the status bar and header.
        .ignoresSafeArea(edges: .top)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .top) { header }
    }

    // MARK: Header

    private var header: some View {
        TabHeader(title: "Stores", location: $location, locations: locations)
    }

    // MARK: Section chrome

    /// Centred, letter-spaced section title between two hairlines.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: R.spacingSpace20) {
            HStack(spacing: R.spacingSpace16) {
                hairline(fadingTo: .leading)
                // Label 1's face and size with wide letter-spacing (the named style fixes its own tracking).
                Text(title.uppercased())
                    .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .callout))
                    .tracking(2.6)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize()
                    .accessibilityAddTraits(.isHeader)
                hairline(fadingTo: .trailing)
            }
            .padding(.horizontal, R.spacingSpace16)
            content()
        }
    }

    private func hairline(fadingTo edge: Edge) -> some View {
        LinearGradient(colors: [M.borderModerate, M.borderModerate.opacity(0)],
                       startPoint: edge == .leading ? .trailing : .leading,
                       endPoint: edge == .leading ? .leading : .trailing)
            .frame(height: R.stroke1Px)
            .accessibilityHidden(true)
    }

    // MARK: Shop by category

    private var categories: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.fixed(124), spacing: R.spacingSpace12), GridItem(.fixed(124))],
                      spacing: R.spacingSpace12) {
                ForEach(StoresData.categories, id: \.name) { c in
                    // The artwork carries its own title and dark tile.
                    Image(c.asset)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 92, height: 124)
                        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
                        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                        .accessibilityElement()
                        .accessibilityLabel(c.name)
                        .accessibilityAddTraits(.isButton)
                }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: What's new in stores

    private var whatsNew: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace12) {
                ForEach(StoresData.newIn) { item in
                    NewInStoreCard(item: item, isSaved: saved.contains(item.id)) { toggleSaved(item.id) }
                }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: District benefits

    private var benefits: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                benefitTitle("In-store", "offers")
                Text("Available at the store")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                HStack(spacing: R.spacingSpace8) {
                    Image(systemName: "plus").font(.system(size: 12, weight: .semibold)).foregroundStyle(M.textOffer)
                    Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
                }
                .accessibilityHidden(true)
                benefitTitle("District", "offers")
                Text("When you pay on District")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            .padding(R.spacingSpace16)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))

            VStack(spacing: R.spacingSpace12) {
                benefitTile(lead: "Pay in 3", accent: "EMI", detail: "0% interest")
                benefitTile(lead: "Bank", accent: "offers", detail: "On select cards")
            }
            .frame(maxWidth: .infinity)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(R.spacingSpace12)
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .padding(.horizontal, R.spacingSpace16)
    }

    private func benefitTitle(_ lead: String, _ accent: String) -> some View {
        (Text(lead + " ").foregroundStyle(M.textPrimary) + Text(accent).foregroundStyle(M.textOffer))
            .backstageText(.label1)
            .accessibilityAddTraits(.isHeader)
    }

    private func benefitTile(lead: String, accent: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            benefitTitle(lead, accent)
            Text(detail)
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
        }
        .padding(R.spacingSpace16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .accessibilityElement(children: .combine)
    }

    // MARK: In your district

    private var collections: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                ForEach(StoresData.collections, id: \.title) { CollectionCard(collection: $0) }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: All stores

    private var stores: [Store] {
        let list = StoresData.stores.filter {
            switch offerFilter {
            case .all: true
            case .inStore: $0.inStoreOffer
            case .district: !$0.inStoreOffer
            }
        }
        return sort == .distance ? list.sorted { $0.distance < $1.distance } : list.sorted { $0.name < $1.name }
    }

    private var allStores: some View {
        VStack(spacing: R.spacingSpace24) {
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    Menu {
                        Picker("Sort by", selection: $sort) {
                            ForEach(StoreSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                    } label: {
                        filterLabel("Filters", icon: "slider.horizontal.3", active: sort != .distance)
                    }
                    Button { toggle(.inStore) } label: {
                        filterLabel("In-store offers", active: offerFilter == .inStore)
                    }
                    Button { toggle(.district) } label: {
                        filterLabel("District offers", active: offerFilter == .district)
                    }
                }
                .buttonStyle(.plain)
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollIndicators(.hidden)

            LazyVStack(spacing: R.spacingSpace0) {
                ForEach(Array(stores.enumerated()), id: \.element.id) { i, store in
                    if i > 0 {
                        Rectangle().fill(M.surfacePrimary).frame(height: R.spacingSpace8)
                    }
                    StoreRow(store: store, isSaved: saved.contains(store.id)) { toggleSaved(store.id) }
                        .padding(.vertical, R.spacingSpace24)
                }
            }
            .animation(.snappy, value: offerFilter)
            .animation(.snappy, value: sort)
        }
    }

    private func filterLabel(_ title: String, icon: String? = nil, active: Bool) -> some View {
        HStack(spacing: R.spacingSpace8) {
            if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
            Text(title)
            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
        }
        .backstageText(.label2)
        .foregroundStyle(active ? M.buttonFilterLabelActive : M.buttonFilterLabel)
        .padding(.horizontal, R.spacingSpace16)
        .frame(height: 36)
        .background(active ? M.buttonFilterBackgroundActive : M.buttonFilterBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(active ? M.buttonFilterBorderActive : M.buttonFilterBorder, lineWidth: R.stroke1Px))
        .padding(.vertical, R.spacingSpace4)
        .contentShape(Capsule())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func toggle(_ filter: OfferFilter) {
        offerFilter = offerFilter == filter ? .all : filter
    }

    private func toggleSaved(_ id: String) {
        if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
    }
}

private enum OfferFilter { case all, inStore, district }
private enum StoreSort: String, CaseIterable { case distance = "Distance", name = "Name" }

// MARK: - District glow

/// The District green wash at the top of the Search tab (Stores has the banner instead).
struct DistrictGlow: View {
    var body: some View {
        RadialGradient(colors: [M.brandGreen900, M.brandGreen900.opacity(0.35), .clear],
                       center: UnitPoint(x: 0.5, y: 0), startRadius: 0, endRadius: 360)
            .frame(height: 320)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

// MARK: - Tab header

/// Header shared by the Stores and Explore tabs: District home button, the tab title over a
/// location picker, and the profile avatar. `subtitle` replaces the location line when set (the
/// Explore tab shows the section being read).
struct TabHeader: View {
    let title: String
    @Binding var location: String
    let locations: [String]
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "house", label: "District home")

            Menu {
                Picker("Location", selection: $location) {
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: R.spacingSpace0) {
                    Text(title)
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                    HStack(spacing: R.spacingSpace4) {
                        if let subtitle {
                            Text(subtitle).lineLimit(1)
                        } else {
                            Text(location).lineLimit(1)
                            Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                        }
                    }
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .id(subtitle ?? location)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                }
                .clipped()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .shadow(color: M.effectsBlackShadow16, radius: 6, y: 1)
            }
            .accessibilityLabel(subtitle.map { "\(title), \($0)" } ?? "\(title), location \(location)")
            .accessibilityHint("Changes location")

            Spacer(minLength: 0)

            Button {} label: {
                Text("N")
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(M.surfaceSecondary, in: Circle())
                    .overlay(Circle().strokeBorder(M.textPurple, lineWidth: R.stroke2Px))
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
        .animation(.easeInOut(duration: 0.3), value: subtitle)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - Promo banner

/// Full-width campaign banner at the very top of the page, at the artwork's exact proportions. The artwork carries its own copy and
/// "Know more" pill; an invisible button sits over the pill so it stays tappable.
struct PromoBanner: View {
    let image: String
    /// What VoiceOver reads for the artwork's copy.
    let label: String
    /// The pill's centre in the artwork, as a fraction of its size.
    var pillCentre = UnitPoint(x: 0.5, y: 0.913)
    var action: () -> Void = {}

    /// Artwork proportions (804 × 782).
    private let aspect: CGFloat = 804.0 / 782.0

    var body: some View {
        Image(image)
            .resizable()
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    Button(action: action) {
                        Color.clear
                            .frame(width: geo.size.width * 0.3, height: max(44, geo.size.height * 0.08))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .position(x: pillCentre.x * geo.size.width, y: pillCentre.y * geo.size.height)
                    .accessibilityLabel("Know more")
                }
            }
            // The artwork carries its own top gradient and rounded corners, so it's shown as is.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

// MARK: - Cards

/// A store's new arrivals: campaign photo, store identity, three products and the offer.
struct NewInStoreCard: View {
    let item: NewInStore
    let isSaved: Bool
    let toggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            ArtView(art: Art(item.cover, [0x222233, 0x553377]))
                .frame(height: 200)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, M.surfacePrimary], startPoint: .top, endPoint: .bottom).frame(height: 80)
                }
                .overlay(alignment: .topTrailing) {
                    BookmarkButton(isSaved: isSaved, action: toggleSave).padding(R.spacingSpace12)
                }
                .clipped()
                .padding(.bottom, -R.spacingSpace40)

            HStack(spacing: R.spacingSpace12) {
                BrandMark(brand: item.brand, mark: item.mark, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .backstageText(.label2)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text("\(item.distance) • \(item.area)")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, R.spacingSpace12)

            HStack(spacing: R.spacingSpace8) {
                ForEach(item.products, id: \.self) { name in
                    ArtView(art: Art(name, [0x333333, 0x777777]))
                        .frame(height: 92)
                        .frame(maxWidth: .infinity)
                        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                }
            }
            .padding(.horizontal, R.spacingSpace12)

            OfferBar(text: item.offer)
                .padding(.horizontal, R.spacingSpace12)
                .padding(.bottom, R.spacingSpace12)
        }
        .frame(width: 318)
        .background(M.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .accessibilityElement(children: .contain)
    }
}

/// A curated set of nearby stores with their offers.
struct CollectionCard: View {
    let collection: StoreCollection

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(collection.title)
                        .backstageText(.label1)
                        .foregroundStyle(M.textOffer)
                        .accessibilityAddTraits(.isHeader)
                    Text(collection.subtitle)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                }
                Spacer(minLength: R.spacingSpace8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(M.iconPrimary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                ForEach(collection.stores, id: \.name) { s in
                    HStack(spacing: R.spacingSpace16) {
                        BrandMark(brand: s.name, mark: s.mark, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .backstageText(.label2)
                                .foregroundStyle(M.textPrimary)
                            Text("\(s.distance) • \(s.area)")
                                .backstageText(.body3)
                                .foregroundStyle(M.textSecondary)
                                .lineLimit(1)
                            HStack(spacing: R.spacingSpace4) {
                                Image(systemName: "tag.fill").font(.system(size: 11))
                                Text(s.offer)
                            }
                            .backstageText(.label3)
                            .foregroundStyle(M.textOffer)
                        }
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(R.spacingSpace16)
        .frame(width: 300, alignment: .topLeading)
        .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }
}

/// One store in the full list: identity, a product rail, the offer and any extras.
struct StoreRow: View {
    let store: Store
    let isSaved: Bool
    let toggleSave: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                BrandMark(brand: store.name, mark: store.mark, size: 56)
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(store.name)
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                    Text(store.categories)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                    HStack(spacing: R.spacingSpace4) {
                        Image(systemName: "mappin.circle").font(.system(size: 12))
                        Text("\(String(format: "%.1f", store.distance)) km • \(store.area)").lineLimit(1)
                    }
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                }
                Spacer(minLength: 0)
                BookmarkButton(isSaved: isSaved, action: toggleSave)
            }
            .padding(.horizontal, R.spacingSpace16)
            .accessibilityElement(children: .combine)

            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace8) {
                    ForEach(store.products, id: \.self) { name in
                        ArtView(art: Art(name, [0x333333, 0x777777]))
                            .frame(width: 104, height: 104)
                            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                OfferBar(text: store.offer)
                if store.noCostEMI {
                    HStack(spacing: R.spacingSpace4) {
                        Image(systemName: "percent").font(.system(size: 11, weight: .bold))
                        Text("No cost EMI")
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 30)
                    .background(M.surfacePrimary, in: Capsule())
                }
            }
            .padding(.horizontal, R.spacingSpace16)
        }
    }
}

/// Purple offer strip that fades out to the right.
struct OfferBar: View {
    let text: String

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Image(systemName: "tag.fill").font(.system(size: 12))
            Text(text)
        }
        .backstageText(.label2)
        .foregroundStyle(M.textPrimary)
        .padding(.horizontal, R.spacingSpace12)
        .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
        .background(
            LinearGradient(colors: [M.surfaceOfferPrimary.opacity(0.55), M.surfaceOfferSecondary.opacity(0.2)], startPoint: .leading, endPoint: .trailing),
            in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8)
        )
        .accessibilityLabel("Offer: \(text)")
    }
}

struct BookmarkButton: View {
    let isSaved: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isSaved ? "bookmark.fill" : "bookmark")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 34, height: 34)
                .background(M.surfaceSecondary.opacity(0.9), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.selection, trigger: isSaved)
        .accessibilityLabel(isSaved ? "Saved" : "Save")
        .accessibilityAddTraits(isSaved ? .isSelected : [])
    }
}

// MARK: - Data

struct NewInStore: Identifiable {
    var id: String { title }
    let title: String
    let brand: String
    let mark: String
    let cover: String
    let distance: String
    let area: String
    let products: [String]
    let offer: String
}

struct StoreCollection {
    struct Entry {
        let name: String
        let mark: String
        let distance: String
        let area: String
        let offer: String
    }
    let title: String
    let subtitle: String
    let stores: [Entry]
}

struct Store: Identifiable {
    var id: String { name }
    let name: String
    let mark: String
    let categories: String
    let distance: Double
    let area: String
    let products: [String]
    let offer: String
    let inStoreOffer: Bool
    let noCostEMI: Bool
}

/// Placeholder content for the Stores tab: offers, distances and areas are illustrative until
/// live store data is wired in.
enum StoresData {
    static let categories: [(name: String, asset: String)] = [
        ("All Stores", "category_all_stores"),
        ("Footwear", "category_footwear"),
        ("Apparel", "category_apparel"),
        ("Accessories", "category_accessories"),
        ("Salon & Wellness", "category_salon_wellness"),
        ("Jewellery", "category_jewellery"),
        ("Home & Furniture", "category_home_furniture"),
        ("Beauty", "category_beauty"),
    ]

    static let newIn: [NewInStore] = [
        NewInStore(title: "Freestyle by Bonkers Corner", brand: "Bonkers Corner", mark: "BNKR", cover: "rack_bonkers_patchwork",
                   distance: "6.9 km", area: "Sector 29, Gurgaon",
                   products: ["rack_bonkers_jeans", "staple_denim_2", "rack_blu_trucker"], offer: "Flat ₹700 OFF"),
        NewInStore(title: "The new season at adidas", brand: "adidas", mark: "adidas", cover: "rack_adidas_popper",
                   distance: "1.7 km", area: "Golf Course Extension, Gurgaon",
                   products: ["rack_adidas_track", "plan_active_1", "plan_active_2"], offer: "Flat ₹1000 OFF"),
        NewInStore(title: "Festive edit at Nicobar", brand: "Nicobar", mark: "NICO\nBAR", cover: "plan_diwali_1",
                   distance: "3.2 km", area: "Ambience Mall, Gurgaon",
                   products: ["rack_nicobar_kaftan", "plan_diwali_2", "plan_wedding_1"], offer: "15% off above ₹4,999"),
    ]

    static let collections: [StoreCollection] = [
        StoreCollection(title: "Women's ethnic wear", subtitle: "Shop the perfect ethnic fits for you", stores: [
            .init(name: "Nicobar", mark: "NICO\nBAR", distance: "3.2 km", area: "Ambience Mall", offer: "Flat ₹300 OFF"),
            .init(name: "Doodlage", mark: "DOOD\nLAGE", distance: "4.1 km", area: "Galleria Market", offer: "Flat ₹300 OFF"),
            .init(name: "Cord", mark: "CORD", distance: "2.5 km", area: "Worldmark, Sector 65", offer: "Flat ₹700 OFF"),
        ]),
        StoreCollection(title: "Streetwear drops", subtitle: "Fresh fits from homegrown labels", stores: [
            .init(name: "Bonkers Corner", mark: "BNKR", distance: "6.9 km", area: "Sector 29", offer: "Flat ₹700 OFF"),
            .init(name: "Snitch", mark: "SNI\nTCH", distance: "2.1 km", area: "Good Earth City Center", offer: "Flat ₹300 OFF"),
            .init(name: "The Souled Store", mark: "TSS", distance: "4.4 km", area: "Galleria Market", offer: "Flat ₹500 OFF"),
        ]),
        StoreCollection(title: "Sneakers & sport", subtitle: "Kicks and kits for every game", stores: [
            .init(name: "adidas", mark: "adidas", distance: "1.7 km", area: "Golf Course Extension", offer: "Flat ₹1000 OFF"),
            .init(name: "Gully Labs", mark: "गली\nLABS", distance: "5.0 km", area: "Cyberhub", offer: "Flat ₹400 OFF"),
        ]),
    ]

    static let stores: [Store] = [
        Store(name: "adidas", mark: "adidas", categories: "Fashion | Footwear • Sports & Outdoors", distance: 1.7,
              area: "Golf Course Extension, Gurgaon", products: ["rack_adidas_popper", "plan_active_1", "plan_active_3", "rack_adidas_track"],
              offer: "Flat ₹1000 OFF", inStoreOffer: false, noCostEMI: true),
        Store(name: "H&M", mark: "H&M", categories: "Fashion | Apparel", distance: 2.4,
              area: "Cyberhub, DLF Phase 2", products: ["rack_hm_overcoat", "staple_white_tee_1", "palette_slate-noir_2", "staple_blazer_2"],
              offer: "Flat ₹500 OFF", inStoreOffer: true, noCostEMI: false),
        Store(name: "Zara", mark: "ZARA", categories: "Fashion | Apparel • Accessories", distance: 2.6,
              area: "Cyberhub, DLF Phase 2", products: ["rack_zara_dress", "rack_zara_blazer", "plan_office_1", "plan_office_3"],
              offer: "Bank offers available", inStoreOffer: false, noCostEMI: true),
        Store(name: "Nicobar", mark: "NICO\nBAR", categories: "Fashion | Ethnic • Home", distance: 3.2,
              area: "Ambience Mall, Gurgaon", products: ["rack_nicobar_kaftan", "plan_diwali_1", "plan_wedding_3", "palette_rose-clay_2"],
              offer: "15% off above ₹4,999", inStoreOffer: true, noCostEMI: false),
        Store(name: "Snitch", mark: "SNI\nTCH", categories: "Fashion | Menswear", distance: 2.1,
              area: "Good Earth City Center, Sector 50", products: ["rack_snitch_biker", "staple_denim_1", "palette_midnight-olive_3", "staple_blazer_3"],
              offer: "Flat ₹300 OFF", inStoreOffer: false, noCostEMI: false),
        Store(name: "Bonkers Corner", mark: "BNKR", categories: "Fashion | Streetwear", distance: 6.9,
              area: "Sector 29, Gurgaon", products: ["rack_bonkers_patchwork", "rack_bonkers_jeans", "staple_white_tee_3", "palette_butter-denim_3"],
              offer: "Flat ₹700 OFF", inStoreOffer: true, noCostEMI: true),
    ]
}

#Preview {
    StoresView().preferredColorScheme(.dark)
}
