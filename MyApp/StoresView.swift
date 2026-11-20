import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Stores tab, as on the District app: the virtual try-on hero, categories, new-in-store highlights, bank offers,
/// District benefits, malls ("Discover top brands"), What's hot edits, curated collections near you and the full
/// store list. Artwork the app doesn't have yet is cut from the reference screens (Assets › StoresHome).
struct StoresView: View {
    @State private var location = "International Tech Park"
    @State private var saved: Set<String> = []
    @State private var offerFilter: OfferFilter = .all
    @State private var sort: StoreSort = .relevance
    @State private var productDrops: ProductDropsPresentation? = StoresView.launchProductDrops
    @State private var product: StoreProduct? = StoresView.launchProduct
    @State private var storePage: StoreDetail? = StoresView.launchStore
    @State private var occasion: OccasionEdit? = StoresView.launchOccasion
    @State private var mallVisit: MallVisit? = StoresView.launchMall
    @State private var tryingOn = false
    @Namespace private var dropZoom

    /// Where the floating header ends, and whether the page has moved under it / the store filters have reached it.
    @State private var headerBottom: CGFloat = 0
    /// Where the header starts (the top safe area), so the hero art can sit under it as on the reference phone.
    @State private var headerTop: CGFloat = 0
    @State private var isScrolled = false
    @State private var filtersStuck = false

    private let locations = ["International Tech Park", "Vatika City", "Golf Course Extension Road", "Cyberhub, DLF Phase 2"]
    private static let page = "storesPage"

    /// Debug builds accept `-openProductDrops` to open straight on the product drops flow.
    private static var launchProductDrops: ProductDropsPresentation? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-openProductDrops") { return ProductDropsPresentation() }
        #endif
        return nil
    }

    /// Debug builds accept `-openStorePDP <photo>` to open a store piece's product page.
    private static var launchProduct: StoreProduct? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-openStorePDP"), i + 1 < args.count {
            let image = args[i + 1]
            let store = StoresData.stores.first { $0.products.contains(image) }?.name
                ?? StoresData.newIn.first { $0.products.contains(image) }?.brand ?? "adidas"
            return StoreProduct.from(image: image, store: store)
        }
        #endif
        return nil
    }

    /// Debug builds accept `-openOccasion` to open the first "Shop for occasion" edit.
    private static var launchOccasion: OccasionEdit? {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-openOccasion") { return OccasionData.edits.first }
        #endif
        return nil
    }

    /// Debug builds accept `-openMall [name]` to open "Shop a mall" on that mall's canvas, plus `-mallEdit <id|picks>`
    /// to open an edit (e.g. `brand-Zara`), `-mallSaved` to start with three pieces saved and `-mallSwitcher` to open
    /// the mall dropdown.
    private static var launchMall: MallVisit? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-openMall") else { return nil }
        let name = i + 1 < args.count && !args[i + 1].hasPrefix("-") ? args[i + 1] : nil
        let mall = name.flatMap(MallCatalog.mall(named:)) ?? MallCatalog.malls[0]
        let edit = args.firstIndex(of: "-mallEdit").flatMap { $0 + 1 < args.count ? args[$0 + 1] : nil }
        return MallVisit(mall: mall, startEdit: edit, presaved: args.contains("-mallSaved"),
                         showSwitcher: args.contains("-mallSwitcher"))
        #else
        return nil
        #endif
    }

    #if DEBUG
    private static var launchAnchor: UnitPoint {
        let args = ProcessInfo.processInfo.arguments
        if args.contains("-storesBottom") { return .bottom }
        if let i = args.firstIndex(of: "-storesAnchor"), i + 1 < args.count, let y = Double(args[i + 1]) { return UnitPoint(x: 0.5, y: y) }
        return .top
    }
    #endif

    /// Debug builds accept `-openStore <name>` to open a store's page.
    private static var launchStore: StoreDetail? {
        #if DEBUG
        let args = ProcessInfo.processInfo.arguments
        if let i = args.firstIndex(of: "-openStore"), i + 1 < args.count,
           let store = StoresData.stores.first(where: { $0.name == args[i + 1] }) {
            return StoreDetail.of(store)
        }
        #endif
        return nil
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: R.spacingSpace0) {
                tryOnHero
                    // The header turns into a frosted bar once the hero has gone under it.
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.page)).maxY } action: { y in
                        let scrolled = y < headerBottom + R.spacingSpace24
                        if scrolled != isScrolled { isScrolled = scrolled }
                    }

                // The previous Stores home opened on "Shop a mall" right under the hero. It's switched off for now;
                // uncomment to bring it back. The mall view (MallDiscoveryView.swift) is untouched and still opens
                // with `-openMall`.
                // A whole mall's catalogue: a moving wall of its brands that opens on a canvas of its brands and edits.
                // Carries its own "Shop in <mall> ⌄" heading, in Home's section style, instead of the centred title.
                // MallEntry(paused: mallVisit != nil) { mall, edit in
                //     // The mall view runs its own entrance over this page.
                //     var t = Transaction()
                //     t.disablesAnimations = true
                //     withTransaction(t) { mallVisit = MallVisit(mall: mall, startEdit: edit) }
                // }
                //     .padding(.top, R.spacingSpace40)

                // "Shop for occasion" is switched off too; uncomment to bring the rail back. The gallery
                // (OccasionTryOn.swift) is untouched and still opens with `-openOccasion`.
                // section("Shop for occasion") { ShopForOccasionRail { occasion = $0 } }

                section("Shop by category") { categories }
                    .padding(.top, R.spacingSpace20)
                section("What's new in stores") { whatsNew }
                    .padding(.top, R.spacingSpace48)
                section("Bank offers") { bankOffers }
                    .padding(.top, R.spacingSpace48)
                section("District benefits") { benefits }
                    .padding(.top, R.spacingSpace40)
                discoverBrands
                    .padding(.top, R.spacingSpace48)
                section("What's hot") { whatsHot }
                    .padding(.top, R.spacingSpace40)
                section("In your district") { collections }
                    .padding(.top, R.spacingSpace48)
                section("All stores") { allStores }
                    .padding(.top, R.spacingSpace48)
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        #if DEBUG
        // `-storesBottom` opens the page scrolled to the end, `-storesAnchor <0…1>` part of the way down.
        .defaultScrollAnchor(Self.launchAnchor)
        #endif
        // The hero starts at the very top, behind the status bar and header.
        .ignoresSafeArea(edges: .top)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .top) { floatingHeader }
        .coordinateSpace(name: Self.page)
        .readerCover(item: $productDrops) { _ in
            ProductDropsView().zoomTransition(id: "product-drops", in: dropZoom)
        }
        .readerCover(item: $storePage) { StoreDetailView(detail: $0) }
        .readerCover(item: $occasion) { OccasionGalleryView(edit: $0) }
        .readerCover(item: $mallVisit) { MallDiscoveryView(visit: $0) }
        .readerCover(item: $product) { p in
            StoreProductView(product: p).zoomTransition(id: Self.zoomID(p.image, p.store), in: dropZoom)
        }
        .fullScreenCover(isPresented: $tryingOn) {
            VirtualTryOnView(title: "Virtual try-on", art: Art("vto_outfit", [0x2A2A2E, 0x6A6A70]))
        }
    }

    // MARK: Hero

    /// "Introducing virtual try-on": full-bleed artwork (copy and "Get started" pill baked in) with rounded bottom
    /// corners; an invisible button over the pill opens try-on.
    private var tryOnHero: some View {
        PromoBanner(image: "sh_tryon_hero",
                    label: "Introducing virtual try-on. Try on your favourite outfits",
                    pillCentre: UnitPoint(x: 0.5, y: 0.898),
                    aspect: 1170.0 / 1169.0,
                    pillLabel: "Get started") { tryingOn = true }
            // The art is laid out for a header starting 44pt down the screen; where the status bar is taller it moves
            // down by the difference (the band above is the art's own top tone) so the header still clears the arch.
            .padding(.top, heroDrop)
            .background(alignment: .top) { Color.tryOnHeroTop.frame(height: heroDrop + 2) }
    }

    private var heroDrop: CGFloat { max(0, headerTop - 44) }

    // MARK: Header

    private var floatingHeader: some View {
        VStack(spacing: R.spacingSpace0) {
            TabHeader(title: "Stores", location: $location, locations: locations, avatar: "sh_avatar")
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.page)).maxY } action: { headerBottom = $0 }
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { headerTop = $0 }
            if filtersStuck {
                filterRow
                    .padding(.bottom, R.spacingSpace8)
            }
        }
        .background {
            if isScrolled || filtersStuck {
                StoresHeaderBackdrop()
                    .ignoresSafeArea(edges: .top)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: isScrolled)
    }

    // MARK: Section chrome

    /// Centred, letter-spaced section title between two hairlines.
    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: R.spacingSpace16) {
            SectionTitle(title: title)
            content()
        }
    }

    // MARK: Shop by category

    private var categories: some View {
        ScrollView(.horizontal) {
            LazyHGrid(rows: [GridItem(.fixed(101), spacing: R.spacingSpace16), GridItem(.fixed(101))],
                      spacing: R.spacingSpace16) {
                ForEach(StoresData.categories) { CategoryTile(category: $0) }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: What's new in stores

    private var whatsNew: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace16) {
                ForEach(StoresData.newIn) { item in
                    NewInStoreCard(item: item, isSaved: saved.contains(item.id), toggleSave: { toggleSaved(item.id) },
                                   zoom: dropZoom, openStore: { openStore(item.brand) }) { open($0, at: item.brand) }
                }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: Bank offers

    private var bankOffers: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace16) {
                ForEach(StoresData.bankOffers) { BankOfferCard(offer: $0) }
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
                    Image(systemName: "plus").font(.system(size: 14, weight: .semibold)).foregroundStyle(Color.benefitAccent)
                    LinearGradient(colors: [M.borderModerate, M.borderModerate.opacity(0)], startPoint: .leading, endPoint: .trailing)
                        .frame(height: R.stroke1Px)
                }
                .accessibilityHidden(true)
                benefitTitle("District", "offers")
                Text("When you pay via District")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            .padding(R.spacingSpace12)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(benefitFill, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))

            VStack(spacing: R.spacingSpace12) {
                benefitTile {
                    benefitTitle("Pay in 3", "EMI")
                    Text("0% interest")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                }
                benefitTile {
                    benefitTitle("Bank", "offers")
                    BankLogoStack(logos: ["sdp_ic_icici", "pd_bank_hdfc", "pd_bank_hsbc"])
                }
            }
            // A little narrower than half, as in the app, so the left tile's lines stay on one line each.
            .frame(width: 144)
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(R.spacingSpace12)
        .overlay(
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner20)
                .strokeBorder(LinearGradient(colors: [Color.benefitAccent.opacity(0.35), M.borderSubtle],
                                             startPoint: .top, endPoint: .bottom), lineWidth: R.stroke1Px)
        )
        .padding(.horizontal, R.spacingSpace16)
    }

    private var benefitFill: LinearGradient {
        LinearGradient(colors: [M.surfacePrimary, M.surfacePrimary.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func benefitTitle(_ lead: String, _ accent: String) -> some View {
        (Text(lead + " ").foregroundStyle(M.textPrimary) + Text(accent).foregroundStyle(Color.benefitAccent))
            .backstageText(.label1)
            .accessibilityAddTraits(.isHeader)
    }

    private func benefitTile<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) { content() }
            .padding(R.spacingSpace12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(benefitFill, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            .accessibilityElement(children: .combine)
    }

    // MARK: Discover top brands (malls)

    /// The "Discover top brands, all in one place" band with the malls carousel sitting in its purple wash.
    private var discoverBrands: some View {
        VStack(spacing: R.spacingSpace0) {
            Image("sh_discover_band")
                .resizable()
                .aspectRatio(1170.0 / 296.0, contentMode: .fit)
                .frame(maxWidth: .infinity)
                .accessibilityLabel("Discover top brands, all in one place")
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace12) {
                    ForEach(StoresData.malls) { MallCard(mall: $0) }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .background {
                // The band's purple carries on behind the cards and fades back into the page.
                LinearGradient(stops: [.init(color: Color.discoverWash, location: 0),
                                       .init(color: Color.discoverWash.opacity(0.55), location: 0.45),
                                       .init(color: Color.discoverWash.opacity(0), location: 1)],
                               startPoint: .top, endPoint: .bottom)
                    .accessibilityHidden(true)
            }
        }
    }

    // MARK: What's hot

    private var whatsHot: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace16) {
                HotEditCard(label: "After hours glam. Date night outfits, by District") {
                    Image("sh_hot_date_night").resizable().scaledToFill()
                }
                HotEditCard(label: "Made to stand out. For her wardrobe, by District") {
                    // Overlays, so the oversized model photo is cropped by the card instead of sizing it.
                    Color.forHerGreen
                        .overlay(alignment: .leading) {
                            Image("sh_hot_for_her_copy")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 145)
                        }
                        .overlay(alignment: .topLeading) {
                            Image("mall_cut_sdp_cat_c2_b2")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 230)
                                .offset(x: 112, y: -30)
                        }
                }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: In your district

    private var collections: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                ForEach(StoresData.collections, id: \.title) { CollectionCard(collection: $0, openStore: openStore) }
            }
            .scrollTargetLayout()
        }
        .carousel()
    }

    // MARK: All stores

    private var stores: [Store] {
        let list = StoresData.homeStores.filter {
            switch offerFilter {
            case .all: true
            case .inStore: $0.inStoreOffer
            case .district: !$0.inStoreOffer
            }
        }
        switch sort {
        case .relevance: return list
        case .distance: return list.sorted { $0.distance < $1.distance }
        case .name: return list.sorted { $0.name < $1.name }
        }
    }

    private var allStores: some View {
        VStack(spacing: R.spacingSpace0) {
            // Tells the header when the filters below have reached it.
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .named(Self.page)).minY } action: { y in
                    let stuck = y <= headerBottom + 1
                    if stuck != filtersStuck { filtersStuck = stuck }
                }
            // Stays in the page at rest; the header takes over once it reaches the top.
            filterRow
                .opacity(filtersStuck ? 0 : 1)
                .padding(.top, R.spacingSpace8)
                .padding(.bottom, R.spacingSpace4)

            LazyVStack(spacing: R.spacingSpace0) {
                ForEach(Array(stores.enumerated()), id: \.element.id) { i, store in
                    if i > 0 {
                        Rectangle().fill(M.surfaceSecondary).frame(height: R.spacingSpace4)
                    }
                    StoreRow(store: store, isSaved: saved.contains(store.id), toggleSave: { toggleSaved(store.id) },
                             zoom: dropZoom, openStore: { storePage = StoreDetail.of(store) }) { open($0, at: store.name) }
                        .padding(.vertical, R.spacingSpace16)
                }
            }
            .animation(.snappy, value: offerFilter)
            .animation(.snappy, value: sort)
        }
    }

    private var filterRow: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Menu {
                    Picker("Sort by", selection: $sort) {
                        ForEach(StoreSort.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                } label: {
                    filterLabel("Filters", icon: "slider.horizontal.3", emphasised: true, active: sort != .relevance)
                }
                Button { toggle(.inStore) } label: {
                    filterLabel("In-store offers", active: offerFilter == .inStore)
                }
                Button { toggle(.district) } label: {
                    filterLabel("District offers", chevron: false, active: offerFilter == .district)
                }
            }
            .buttonStyle(.plain)
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func filterLabel(_ title: String, icon: String? = nil, emphasised: Bool = false, chevron: Bool = true,
                             active: Bool) -> some View {
        HStack(spacing: R.spacingSpace8) {
            if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
            Text(title).font(.custom(emphasised ? "BeVietnamPro-SemiBold" : "BeVietnamPro-Medium", size: 14, relativeTo: .subheadline))
            if chevron { Image(systemName: "chevron.down").font(.system(size: 11, weight: .semibold)) }
        }
        .foregroundStyle(active ? M.buttonFilterLabelActive : M.buttonFilterLabel)
        .padding(.horizontal, R.spacingSpace12)
        .frame(height: 32)
        .background(active ? M.buttonFilterBackgroundActive : M.buttonFilterBackground, in: Capsule())
        .overlay(Capsule().strokeBorder(active ? M.buttonFilterBorderActive : M.buttonFilterBorder, lineWidth: R.stroke1Px))
        .padding(.vertical, R.spacingSpace4)
        .contentShape(Capsule())
        .accessibilityAddTraits(active ? .isSelected : [])
    }

    private func toggle(_ filter: OfferFilter) {
        offerFilter = offerFilter == filter ? .all : filter
    }

    /// A store's name or card opens its store page, when the store is in the list.
    private func openStore(_ name: String) {
        if let store = StoresData.stores.first(where: { $0.name == name }) { storePage = StoreDetail.of(store) }
    }

    /// A piece from a store's rail opens its product page.
    private func open(_ image: String, at store: String) {
        product = StoreProduct.from(image: image, store: store)
    }

    /// Zoom ids pair the photo with its store, since a photo can sit on more than one rail.
    static func zoomID(_ image: String, _ store: String) -> String { "store-pdp-\(store)-\(image)" }

    private func toggleSaved(_ id: String) {
        if saved.contains(id) { saved.remove(id) } else { saved.insert(id) }
    }
}

private enum OfferFilter { case all, inStore, district }
private enum StoreSort: String, CaseIterable { case relevance = "Relevance", distance = "Distance", name = "Name" }

private extension Color {
    /// District benefits' light-blue accent ("offers", "EMI" and the plus).
    static let benefitAccent = Color(rgba: 0xA8D4FEFF)
    /// The "Discover top brands" band's purple, where it meets the mall cards.
    static let discoverWash = Color(rgba: 0x160D3AFF)
    /// "For her wardrobe" card.
    static let forHerGreen = Color(rgba: 0xC8EE8FFF)
    /// The try-on hero art's top row.
    static let tryOnHeroTop = Color(rgba: 0x111014FF)
}

// MARK: - Section title

/// Centred, letter-spaced section title between two hairlines.
struct SectionTitle: View {
    let title: String

    var body: some View {
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
    }

    private func hairline(fadingTo edge: Edge) -> some View {
        LinearGradient(colors: [M.borderModerate, M.borderModerate.opacity(0)],
                       startPoint: edge == .leading ? .trailing : .leading,
                       endPoint: edge == .leading ? .leading : .trailing)
            .frame(height: R.stroke1Px)
            .accessibilityHidden(true)
    }
}

// MARK: - Header backdrop

/// Once the page moves under it, the Stores header sits on a frosted bar lit by District green, with a hairline.
private struct StoresHeaderBackdrop: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        GeometryReader { g in
            ZStack(alignment: .top) {
                if reduceTransparency {
                    M.backgroundPrimary
                } else {
                    Rectangle().fill(.ultraThinMaterial)
                    M.backgroundPrimary.opacity(0.6)
                }
                RadialGradient(colors: [M.brandGreen900, M.brandGreen900.opacity(0.4), .clear],
                               center: .top, startRadius: 0, endRadius: g.size.width * 0.8)
            }
            .overlay(alignment: .bottom) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

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
/// location picker, and the profile avatar.
struct TabHeader: View {
    let title: String
    @Binding var location: String
    let locations: [String]
    /// The For You landing is the District home, so it hides its own home button.
    var showsHomeButton = true
    /// A profile picture (with its ring) in place of the initial.
    var avatar: String? = nil
    @Environment(\.districtHomeAction) private var goHome

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            if showsHomeButton {
                GlassIconButton(systemName: "house", label: "District home") { goHome() }
            }

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
                        Text(location).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .id(location)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                }
                .clipped()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
                .shadow(color: M.effectsBlackShadow16, radius: 6, y: 1)
            }
            .accessibilityLabel("\(title), location \(location)")
            .accessibilityHint("Changes location")

            Spacer(minLength: 0)

            Button {} label: {
                Group {
                    if let avatar {
                        Image(avatar)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 37, height: 37)
                            .clipShape(Circle())
                    } else {
                        Text("N")
                            .backstageText(.label1)
                            .foregroundStyle(M.textPrimary)
                            .frame(width: 40, height: 40)
                            .background(M.surfaceSecondary, in: Circle())
                            .overlay(Circle().strokeBorder(M.textPurple, lineWidth: R.stroke2Px))
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
        .animation(.easeInOut(duration: 0.3), value: location)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - Promo banner

/// Full-width campaign banner at the very top of the page, at the artwork's exact proportions. The artwork carries its own copy and
/// pill; an invisible button sits over the pill so it stays tappable.
struct PromoBanner: View {
    let image: String
    /// What VoiceOver reads for the artwork's copy.
    let label: String
    /// The pill's centre in the artwork, as a fraction of its size.
    var pillCentre = UnitPoint(x: 0.5, y: 0.913)
    /// Artwork proportions (width / height); the default is the 804 × 782 campaign artwork.
    var aspect: CGFloat = 804.0 / 782.0
    /// What VoiceOver reads for the pill.
    var pillLabel = "Know more"
    var action: () -> Void = {}

    var body: some View {
        Image(image)
            .resizable()
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                GeometryReader { geo in
                    Button(action: action) {
                        Color.clear
                            .frame(width: geo.size.width * 0.36, height: max(44, geo.size.height * 0.08))
                            .contentShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .position(x: pillCentre.x * geo.size.width, y: pillCentre.y * geo.size.height)
                    .accessibilityLabel(pillLabel)
                }
            }
            // The artwork carries its own top gradient and rounded corners, so it's shown as is.
            .accessibilityElement(children: .contain)
            .accessibilityLabel(label)
    }
}

// MARK: - Cards

/// A "Shop by category" tile. Most carry their title and art in the artwork; the rest are drawn on an empty tile.
struct CategoryTile: View {
    let category: StoreCategory

    var body: some View {
        Group {
            if let tile = category.tile {
                Image(tile).resizable()
            } else {
                Image("sh_cat_blank")
                    .resizable()
                    .overlay(alignment: .bottomTrailing) {
                        if let cutout = category.cutout {
                            Image(cutout)
                                .resizable()
                                .scaledToFit()
                                .frame(height: 64)
                                .padding(.trailing, R.spacingSpace8)
                                .padding(.bottom, R.spacingSpace4)
                        }
                    }
                    .overlay(alignment: .topLeading) {
                        Text(category.name)
                            .font(.custom("BeVietnamPro-SemiBold", size: 13, relativeTo: .subheadline))
                            .foregroundStyle(M.textPrimary)
                            .lineLimit(2)
                            .padding(.leading, 9)
                            .padding(.top, R.spacingSpace8)
                    }
            }
        }
        .frame(width: 93, height: 101)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .accessibilityElement()
        .accessibilityLabel(category.name)
        .accessibilityAddTraits(.isButton)
    }
}

/// A store's new arrivals: campaign photo, store identity, three products and the offer.
struct NewInStoreCard: View {
    let item: NewInStore
    let isSaved: Bool
    let toggleSave: () -> Void
    var zoom: Namespace.ID? = nil
    /// Opens the store's page.
    var openStore: () -> Void = {}
    /// Opens a piece's product page.
    var openProduct: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            ArtView(art: Art(item.cover, [0x222233, 0x553377]))
                .frame(height: 235)
                .overlay(alignment: .bottom) {
                    LinearGradient(colors: [.clear, M.surfacePrimary], startPoint: .top, endPoint: .bottom).frame(height: 90)
                }
                .overlay(alignment: .topTrailing) {
                    BookmarkButton(isSaved: isSaved, action: toggleSave).padding(7)
                }
                .clipped()
                .padding(.bottom, -R.spacingSpace40)

            Button(action: openStore) {
            HStack(spacing: R.spacingSpace12) {
                BrandMark(brand: item.brand, mark: item.mark, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.title)
                        .backstageText(.label1)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text("\(item.distance) • \(item.area)")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens the store")
            .padding(.horizontal, R.spacingSpace12)

            HStack(spacing: R.spacingSpace12) {
                ForEach(item.products, id: \.self) { name in
                    Button { openProduct(name) } label: {
                        ArtView(art: Art(name, [0x333333, 0x777777]))
                            .frame(height: 92)
                            .frame(maxWidth: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                            .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                    }
                    .buttonStyle(PressableStyle())
                    .modifier(OptionalZoomSource(id: StoresView.zoomID(name, item.brand), zoom: zoom))
                    .accessibilityLabel(StoreProduct.from(image: name, store: item.brand).name)
                    .accessibilityHint("Opens the product")
                }
            }
            .padding(.horizontal, R.spacingSpace12)

            OfferBar(text: item.offer, height: 28)
                .padding(.horizontal, R.spacingSpace12)
                .padding(.bottom, R.spacingSpace16)
        }
        .frame(width: 325)
        .background(M.surfacePrimary)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .accessibilityElement(children: .contain)
    }
}

/// A card offer: the bank in a chip, the card's name and the offer.
struct BankOfferCard: View {
    let offer: BankOffer

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace8) {
                Image(offer.logo)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner4))
                Text(offer.bank)
                    .font(.custom("BeVietnamPro-Regular", size: 13, relativeTo: .subheadline))
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, R.spacingSpace4)
            .frame(height: 28)
            .background(M.surfaceSecondary.opacity(0.6), in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))

            Text(offer.card.uppercased())
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Text(offer.offer)
                .font(.custom("BeVietnamPro-Medium", size: 15, relativeTo: .subheadline))
                .foregroundStyle(M.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, R.spacingSpace12)
        .frame(width: 198, height: 127, alignment: .topLeading)
        .background(
            LinearGradient(colors: [M.surfacePrimary, M.surfacePrimary.opacity(0.55)], startPoint: .top, endPoint: .bottom),
            in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16)
        )
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .accessibilityElement(children: .combine)
    }
}

/// Bank logos overlapping in white discs.
private struct BankLogoStack: View {
    let logos: [String]

    var body: some View {
        HStack(spacing: -8) {
            ForEach(logos, id: \.self) { logo in
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .padding(R.spacingSpace4)
                    .frame(width: 24, height: 24)
                    .background(M.iconWhite, in: Circle())
                    .clipShape(Circle())
                    .overlay(Circle().strokeBorder(M.surfacePrimary, lineWidth: R.stroke1Px))
            }
        }
        .padding(.top, R.spacingSpace4)
        .accessibilityHidden(true)
    }
}

/// A mall in "Discover top brands": its photo, name and how far / how many stores.
struct MallCard: View {
    let mall: StoreMall

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace0) {
            Image(mall.photo)
                .resizable()
                .scaledToFill()
                .frame(width: 162, height: 101)
                .clipped()
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(mall.name)
                    .backstageText(.label1)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(2, reservesSpace: true)
                Text("\(mall.distance) | \(mall.stores) stores")
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace12)
        }
        .frame(width: 162, alignment: .leading)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderIntense.opacity(0.7), lineWidth: R.stroke1Px))
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// A "What's hot" edit: a 198 × 146 poster card.
private struct HotEditCard<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        content()
            .frame(width: 198, height: 146)
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner4))
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
    }
}

/// A curated set of nearby stores with their offers.
struct CollectionCard: View {
    let collection: StoreCollection
    /// Opens a store's page by name.
    var openStore: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(collection.title)
                        .backstageText(.title2)
                        .foregroundStyle(M.textOffer)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    Text(collection.subtitle)
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: R.spacingSpace8)
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(M.iconPrimary)
                    .accessibilityHidden(true)
            }

            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                ForEach(collection.stores, id: \.name) { s in
                    Button { openStore(s.name) } label: {
                    HStack(spacing: R.spacingSpace16) {
                        BrandMark(brand: s.name, mark: s.mark, size: 59)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.name)
                                .backstageText(.label1)
                                .foregroundStyle(M.textPrimary)
                                .lineLimit(1)
                            Text("\(s.distance) • \(s.area)")
                                .backstageText(.body3)
                                .foregroundStyle(M.textSecondary)
                                .lineLimit(1)
                            HStack(spacing: R.spacingSpace4) {
                                Image(systemName: "tag.fill").font(.system(size: 11))
                                Text(s.offer)
                            }
                            .backstageText(.label2)
                            .foregroundStyle(M.textOffer)
                        }
                        Spacer(minLength: 0)
                    }
                    .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace24)
        .padding(.bottom, R.spacingSpace32)
        .frame(width: 298, alignment: .topLeading)
        .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
    }
}

/// One store in the full list: identity, a product rail, the offer and any extras.
struct StoreRow: View {
    let store: Store
    let isSaved: Bool
    let toggleSave: () -> Void
    var zoom: Namespace.ID? = nil
    /// Opens the store's page.
    var openStore: () -> Void = {}
    /// Opens a piece's product page.
    var openProduct: (String) -> Void = { _ in }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Button(action: openStore) {
                HStack(alignment: .top, spacing: R.spacingSpace12) {
                BrandMark(brand: store.name, mark: store.mark, size: 57)
                VStack(alignment: .leading, spacing: 2) {
                    Text(store.name)
                        .font(.custom("BeVietnamPro-SemiBold", size: 18, relativeTo: .title3))
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
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
                }
                .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityElement(children: .combine)
                .accessibilityHint("Opens the store")
                BookmarkButton(isSaved: isSaved, action: toggleSave)
                    .padding(.top, -5)
            }
            .padding(.horizontal, R.spacingSpace16)

            ScrollView(.horizontal) {
                LazyHStack(spacing: 9) {
                    ForEach(store.products, id: \.self) { name in
                        Button { openProduct(name) } label: {
                            ArtView(art: Art(name, [0x333333, 0x777777]))
                                .frame(width: 106, height: 106)
                                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                        }
                        .buttonStyle(PressableStyle())
                        .modifier(OptionalZoomSource(id: StoresView.zoomID(name, store.name), zoom: zoom))
                        .accessibilityLabel(StoreProduct.from(image: name, store: store.name).name)
                        .accessibilityHint("Opens the product")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()

            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                OfferBar(text: store.offer)
                if store.noCostEMI {
                    HStack(spacing: R.spacingSpace4) {
                        Image(systemName: "percent")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundStyle(M.textInverse)
                            .frame(width: 16, height: 16)
                            .background(M.iconPrimary, in: Circle())
                        Text("No cost EMI")
                    }
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace8)
                    .frame(height: 27)
                    .background(M.surfaceSecondary, in: Capsule())
                }
            }
            .padding(.top, -R.spacingSpace4)
            .padding(.horizontal, R.spacingSpace16)
        }
    }
}

/// A zoom source only when the card is given a namespace to zoom from.
private struct OptionalZoomSource: ViewModifier {
    let id: String
    let zoom: Namespace.ID?

    func body(content: Content) -> some View {
        if let zoom { content.zoomSource(id: id, in: zoom) } else { content }
    }
}

/// Purple offer strip that fades out to the right.
struct OfferBar: View {
    let text: String
    var height: CGFloat = 32

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Image(systemName: "tag.fill").font(.system(size: 12))
            Text(text)
        }
        .backstageText(.title4)
        .foregroundStyle(M.textPrimary)
        .padding(.horizontal, R.spacingSpace12)
        .frame(maxWidth: .infinity, minHeight: height, alignment: .leading)
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
                .frame(width: 32, height: 32)
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

struct StoreCategory: Identifiable {
    var id: String { name }
    let name: String
    /// Finished tile artwork (title and art baked in).
    var tile: String? = nil
    /// Otherwise, a cut-out drawn on an empty tile under the name.
    var cutout: String? = nil
}

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

struct BankOffer: Identifiable {
    var id: String { card }
    let bank: String
    let logo: String
    let card: String
    let offer: String
}

struct StoreMall: Identifiable {
    var id: String { name }
    let name: String
    let photo: String
    let distance: String
    let stores: Int
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
    /// In grid order: the two-row grid fills top to bottom, so each pair is one column.
    static let categories: [StoreCategory] = [
        StoreCategory(name: "Sneakers", tile: "sh_cat_sneakers"),
        StoreCategory(name: "Electronics", tile: "sh_cat_electronics"),
        StoreCategory(name: "Jewellery", tile: "sh_cat_jewellery"),
        StoreCategory(name: "Footwear", tile: "sh_cat_footwear"),
        StoreCategory(name: "Sunglasses", tile: "sh_cat_sunglasses"),
        StoreCategory(name: "Gifting", tile: "sh_cat_gifting"),
        StoreCategory(name: "Sports", cutout: "mall_cut_rack_adidas_track"),
        StoreCategory(name: "Western Casual", cutout: "mall_cut_rack_zara_dress"),
    ]

    static let newIn: [NewInStore] = [
        NewInStore(title: "Anta", brand: "Anta", mark: "ANTA", cover: "sh_new_anta",
                   distance: "6.2 km", area: "Sector 50, Gurgaon",
                   products: ["sh_anta_1", "sh_anta_2", "sh_anta_3"], offer: "Flat ₹700 OFF"),
        NewInStore(title: "Puma", brand: "Puma", mark: "PUMA", cover: "pd_speedcat_hero",
                   distance: "5.2 km", area: "Ambience Mall, Gurgaon",
                   products: ["pd_speedcat", "pd_hot_speedcats", "pd_speedguard_red"], offer: "Flat ₹500 OFF"),
        NewInStore(title: "adidas", brand: "adidas", mark: "adidas", cover: "rack_adidas_popper",
                   distance: "5.0 km", area: "South Point Mall, Golf Course Road",
                   products: ["rack_adidas_track", "plan_active_1", "plan_active_2"], offer: "Flat ₹1000 OFF"),
    ]

    static let bankOffers: [BankOffer] = [
        BankOffer(bank: "Kotak Mahindra Bank", logo: "sh_bank_kotak_solitaire", card: "Solitaire credit card",
                  offer: "Get 20% off up to ₹5000"),
        BankOffer(bank: "Kotak Mahindra Bank", logo: "sh_bank_kotak_private", card: "Kotak Private credit card",
                  offer: "Get 20% OFF up to ₹5000"),
        BankOffer(bank: "HDFC Bank", logo: "pd_bank_hdfc", card: "Regalia Gold credit card",
                  offer: "Get 10% off up to ₹3000"),
    ]

    static let malls: [StoreMall] = [
        StoreMall(name: "Ardee Mall, Ardee City, Gurgaon", photo: "sh_mall_ardee", distance: "7.8 km", stores: 50),
        StoreMall(name: "DLF Summit Plaza, DLF Phase 5", photo: "sh_mall_dlf_summit", distance: "8.9 km", stores: 81),
        StoreMall(name: "Ambience Mall, NH-48, Gurgaon", photo: "hub_ambience", distance: "9.4 km", stores: 120),
    ]

    static let collections: [StoreCollection] = [
        StoreCollection(title: "Street culture rack", subtitle: "The best of street fashion", stores: [
            .init(name: "Snitch", mark: "SNI\nTCH", distance: "4.5 km", area: "M3M Route 65, Sector 65, Gurgaon", offer: "Flat ₹300 OFF"),
            .init(name: "Limited Edt", mark: "LTD\nEDT", distance: "4.6 km", area: "DLF Summit Plaza, DLF Phase 5", offer: "Flat ₹700 OFF"),
            .init(name: "Reliance Trends", mark: "TRENDS", distance: "6.7 km", area: "Sohna Road, Gurgaon", offer: "Bank benefits"),
            .init(name: "Bonkers Corner", mark: "BNKR", distance: "8.2 km", area: "Sector 29, Gurgaon", offer: "Flat ₹700 OFF"),
        ]),
        StoreCollection(title: "Kicks & co.", subtitle: "Better sneakers, closer to you", stores: [
            .init(name: "Puma", mark: "PUMA", distance: "5.2 km", area: "Ambience Mall, Gurgaon", offer: "Flat ₹500 OFF"),
            .init(name: "Limited Edt", mark: "LTD\nEDT", distance: "4.6 km", area: "DLF Summit Plaza, DLF Phase 5", offer: "Flat ₹700 OFF"),
            .init(name: "M&S", mark: "M&S", distance: "7.1 km", area: "Ambience Mall, Gurgaon", offer: "Bank benefits"),
            .init(name: "United Colors of Benetton", mark: "UCB", distance: "3.9 km", area: "Galleria Market, Gurgaon", offer: "Flat ₹400 OFF"),
        ]),
    ]

    /// The "All stores" list on Stores home, in the order the app shows it.
    static let homeStores: [Store] = [
        Store(name: "Joyalukkas", mark: "JOY", categories: "Fashion | Jewellery", distance: 6.5,
              area: "Sector 44, Gurgaon", products: ["sh_joy_1", "sh_joy_2", "sh_joy_3"],
              offer: "Bank benefits", inStoreOffer: true, noCostEMI: false),
        Store(name: "Shoppers Stop", mark: "SS", categories: "Fashion | Apparel", distance: 3.7,
              area: "Sector 54, Gurgaon", products: ["sh_ss_1", "sh_ss_2", "sh_ss_3"],
              offer: "Flat ₹700 OFF", inStoreOffer: false, noCostEMI: true),
        Store(name: "Snitch", mark: "SNI\nTCH", categories: "Fashion | Apparel", distance: 4.5,
              area: "M3M Route 65, Sector 65, Gurgaon", products: ["sh_snitch_1", "sh_snitch_2", "sh_snitch_3", "rack_snitch_biker"],
              offer: "Flat ₹300 OFF", inStoreOffer: false, noCostEMI: true),
        Store(name: "adidas", mark: "adidas", categories: "Fashion | Footwear • Sports & Outdoors", distance: 5.0,
              area: "South Point Mall, Golf Course Road, Gurgaon", products: ["sh_adidas_1", "sh_adidas_2", "sh_adidas_3", "rack_adidas_track"],
              offer: "Flat ₹1000 OFF", inStoreOffer: false, noCostEMI: true),
        Store(name: "Pantaloons", mark: "PANTA\nLOONS", categories: "Fashion | Apparel", distance: 8.8,
              area: "MG Road, Gurgaon", products: ["staple_white_tee_2", "palette_sage-linen_2", "plan_brunch_1", "look_camel_coat"],
              offer: "Flat ₹500 OFF", inStoreOffer: true, noCostEMI: false),
    ]

    /// Every store the app knows: the home list, then stores other screens (hubs, store pages) still look up by name.
    static let stores: [Store] = homeStores + [
        Store(name: "H&M", mark: "H&M", categories: "Fashion | Apparel", distance: 2.4,
              area: "Cyberhub, DLF Phase 2", products: ["rack_hm_overcoat", "staple_white_tee_1", "palette_slate-noir_2", "staple_blazer_2"],
              offer: "Flat ₹500 OFF", inStoreOffer: true, noCostEMI: false),
        Store(name: "Zara", mark: "ZARA", categories: "Fashion | Apparel • Accessories", distance: 2.6,
              area: "Cyberhub, DLF Phase 2", products: ["rack_zara_dress", "rack_zara_blazer", "plan_office_1", "plan_office_3"],
              offer: "Bank offers available", inStoreOffer: false, noCostEMI: true),
        Store(name: "Nicobar", mark: "NICO\nBAR", categories: "Fashion | Ethnic • Home", distance: 3.2,
              area: "Ambience Mall, Gurgaon", products: ["rack_nicobar_kaftan", "plan_diwali_1", "plan_wedding_3", "photo_rose_2"],
              offer: "15% off above ₹4,999", inStoreOffer: true, noCostEMI: false),
        Store(name: "Bonkers Corner", mark: "BNKR", categories: "Fashion | Streetwear", distance: 8.2,
              area: "Sector 29, Gurgaon", products: ["rack_bonkers_patchwork", "rack_bonkers_jeans", "staple_white_tee_3", "palette_butter-denim_3"],
              offer: "Flat ₹700 OFF", inStoreOffer: true, noCostEMI: true),
    ]
}

#Preview {
    StoresView().preferredColorScheme(.dark)
}
