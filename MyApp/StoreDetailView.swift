import SwiftUI
import PhotosUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Figma values the Backstage tokens don't carry yet (file "SDP", 23747:80987).
private enum SDPPalette {
    static let success = Color(rgba: 0x58E487FF)       // color/text/success
    static let grey50 = Color(rgba: 0xFAFAFAFF)        // colors/neutral-grey/50
    static let grey300 = Color(rgba: 0x98989FFF)       // colors/neutral-grey/300
    static let tileFill = Color(rgba: 0xF4F4F4FF)
    static let tileRule = Color(rgba: 0x131316FF)
    static let imageRule = Color(rgba: 0xBFBFC429)
    static let emiPill = Color(rgba: 0x62677299)
    static let purple900 = Color(rgba: 0x160D3BFF)
    static let purple600 = Color(rgba: 0x401CCEFF)
    static let payLabel = Color(rgba: 0x161618FF)
    /// colors/neutral-grey/900, the catalogue screens' page.
    static let pageFill = Color(rgba: 0x131316FF)
    /// The offer strip on "other stores" cards.
    static let offerStrip = LinearGradient(stops: [.init(color: Color(rgba: 0x4B33B4FF), location: 0),
                                                   .init(color: Color(rgba: 0x6444E4FF), location: 0.305),
                                                   .init(color: Color(rgba: 0x8F6FF3FF), location: 0.698),
                                                   .init(color: Color(rgba: 0xB3A6FFFF), location: 1)],
                                           startPoint: .leading, endPoint: .trailing)
}

private typealias P = SDPPalette

#if DEBUG
/// The store screens' launch flags apply once per launch, not to every page opened afterwards.
@MainActor
enum DebugLaunch {
    static var storePageUsed = false
    static var viewerUsed = false
    static var occasionUsed = false
}
#endif

// MARK: - Model

/// One photo in a catalogue collage. `crop` places the photo inside its tile the way the Figma
/// does (in tile points); without it the photo fills the tile.
struct CatalogueTile: Hashable {
    let image: String
    var crop: CGRect? = nil
}

/// A store catalogue: a collage of six pieces (one tall, two stacked, three across the foot).
struct StoreCatalogue: Identifiable, Hashable {
    var id: String { title }
    let title: String
    let tiles: [CatalogueTile]

    func products(at store: String) -> [StoreProduct] { tiles.map { StoreProduct.from(image: $0.image, store: store) } }
    func startingFrom(at store: String) -> Int { products(at: store).map(\.price).min() ?? 0 }
}

/// A store in the same mall, on the "Other stores in …" rail.
struct NearbyStore: Identifiable, Hashable {
    var id: String { name }
    let name: String
    let area: String
    let distance: String
    let image: String
    var crop: CGRect? = nil
}

/// What the store page shows for one store. Illustrative until live store data is wired in.
struct StoreDetail: Identifiable {
    var id: String { store.name }
    let store: Store
    let hero: String
    var logo: String? = nil
    let mall: String
    let catalogues: [StoreCatalogue]
    let about: String

    var categories: (String, String) {
        let parts = store.categories.split(separator: "•").map { $0.trimmingCharacters(in: .whitespaces) }
        return (parts.first ?? store.categories, parts.count > 1 ? parts[1] : "")
    }

    var nearby: [NearbyStore] { StoreDetail.mallStores.filter { $0.name != store.name } }

    /// The catalogue page's collections: the store's catalogues, then everything on its rail.
    var collections: [StoreCatalogue] {
        var rail = store.products
        rail += StoresData.newIn.filter { $0.brand == store.name }.flatMap(\.products)
        var seen = Set<String>()
        let pieces = rail.filter { seen.insert($0).inserted }.map { CatalogueTile(image: $0) }
        return catalogues + [StoreCatalogue(title: store.name == "adidas" ? "Sports wear" : "All pieces", tiles: pieces)]
    }

    static func of(_ store: Store) -> StoreDetail {
        if store.name == "adidas" {
            return StoreDetail(store: store, hero: "plan_active_hero", logo: "sdp_logo_adidas", mall: "Ambience Mall",
                               catalogues: adidasCatalogues,
                               about: "adidas started in a small town in Germany in 1949 to make better shoes for athletes, and today it dresses runners, footballers and street style alike across the world")
        }
        let shots = store.products
        func tiles(_ order: [Int]) -> [CatalogueTile] { order.map { CatalogueTile(image: shots[$0 % shots.count]) } }
        return StoreDetail(store: store, hero: shots[0], mall: "Ambience Mall",
                           catalogues: [StoreCatalogue(title: "New this season", tiles: tiles([0, 1, 2, 3, 1, 2])),
                                        StoreCatalogue(title: "Bestsellers", tiles: tiles([1, 3, 0, 2, 0, 3]))],
                           about: "\(store.name) brings its latest collections to \(store.area), with in-store styling help, easy trials and same-day pick-up when you reserve on District")
    }

    /// The Figma's two catalogues, with each photo placed as it is in the design.
    private static let adidasCatalogues: [StoreCatalogue] = [
        StoreCatalogue(title: "Trendy Winter Outfit", tiles: [
            CatalogueTile(image: "sdp_cat_c1_big", crop: CGRect(x: -25.89, y: -1.51, width: 236.444, height: 296.65)),
            CatalogueTile(image: "sdp_cat_c1_tr", crop: CGRect(x: -21, y: -1, width: 171.519, height: 228.691)),
            CatalogueTile(image: "sdp_cat_c1_mr", crop: CGRect(x: -32.89, y: -22.78, width: 185.111, height: 246.815)),
            CatalogueTile(image: "sdp_cat_c1_b1", crop: CGRect(x: -19.44, y: -1, width: 129.102, height: 174.444)),
            CatalogueTile(image: "sdp_cat_c1_b2", crop: CGRect(x: 0, y: -5.81, width: 100, height: 144.364)),
            CatalogueTile(image: "sdp_cat_c1_b3", crop: CGRect(x: -1.11, y: -1.11, width: 99.743, height: 132.222)),
        ]),
        StoreCatalogue(title: "Easy Summer Dresses", tiles: [
            CatalogueTile(image: "sdp_cat_c2_big", crop: CGRect(x: -26, y: -2, width: 209, height: 278.667)),
            CatalogueTile(image: "sdp_cat_c2_tr", crop: CGRect(x: -21, y: -2.56, width: 169.75, height: 245.05)),
            CatalogueTile(image: "sdp_cat_c2_mr", crop: CGRect(x: -32.75, y: -18.93, width: 178.5, height: 257.21)),
            CatalogueTile(image: "sdp_cat_c2_b1"),
            CatalogueTile(image: "sdp_cat_c2_b2"),
            CatalogueTile(image: "sdp_cat_c2_b3", crop: CGRect(x: -17.99, y: -1.11, width: 115.33, height: 147.25)),
        ]),
    ]

    static let mallStores: [NearbyStore] = [
        NearbyStore(name: "Flying Machine", area: "Cyberhub, Gurgaon", distance: "4.5km", image: "sdp_store_flying_machine",
                    crop: CGRect(x: 0, y: -48.04, width: 183, height: 236.67)),
        NearbyStore(name: "Snitch", area: "Ambience Mall", distance: "4.5km", image: "sdp_store_snitch"),
        NearbyStore(name: "Daily objects", area: "Ambience Mall", distance: "4.5 km", image: "sdp_store_daily_objects"),
    ]
}

// MARK: - Store page

/// The store display page (Figma "SDP", 23747:80987): the store's hero, a sheet with its logo,
/// name, categories and address, quick actions, available offers, catalogues that open the pieces'
/// product pages, the brand story, other stores in the mall, and "Pay bill" at the foot.
struct StoreDetailView: View {
    let detail: StoreDetail
    @Environment(\.dismiss) private var dismiss
    @State private var saved = false
    @State private var readMore = false
    @State private var catalogue: CatalogueRoute?
    @State private var nearby: StoreDetail?
    @State private var tryOnGuide = false

    private static let heroHeight: CGFloat = 289
    /// Where the sheet starts over the hero.
    private static let sheetTop: CGFloat = 273

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    sheet
                }
            }
            .scrollIndicators(.hidden)
            #if DEBUG
            // `-sdpScroll catalogue|stores` opens the page scrolled to that section; `-openCatalogue`
            // opens the catalogue grid.
            .task {
                // Only the first store page of a launch follows the flags, so later pages open normally.
                guard !DebugLaunch.storePageUsed else { return }
                DebugLaunch.storePageUsed = true
                let args = ProcessInfo.processInfo.arguments
                if args.contains("-openCatalogue") { catalogue = CatalogueRoute(collection: 0, tryOnHint: args.contains("-tryOnHint")) }
                if args.contains("-tryOnGuide") { tryOnGuide = true }
                guard let i = args.firstIndex(of: "-sdpScroll"), i + 1 < args.count else { return }
                try? await Task.sleep(for: .seconds(0.8))
                proxy.scrollTo(args[i + 1], anchor: .top)
            }
            #endif
        }
        .ignoresSafeArea(edges: .top)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .overlay(alignment: .top) { header }
        .safeAreaInset(edge: .bottom, spacing: 0) { payBar }
        .readerCover(item: $catalogue) { CatalogueGridView(detail: detail, selected: $0.collection, tryOnHint: $0.tryOnHint) }
        .sheet(isPresented: $tryOnGuide) {
            TryOnEducationSheet(store: detail.store.name) {
                tryOnGuide = false
                // Into the catalogue once the sheet is down, with a pointer to TryOn! waiting.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                    catalogue = CatalogueRoute(collection: 0, tryOnHint: true)
                }
            }
        }
        .readerCover(item: $nearby) { StoreDetailView(detail: $0) }
        .sensoryFeedback(.selection, trigger: saved)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 0) {
            roundButton("sdp_ic_back", label: "Back") { dismiss() }
            Spacer()
            ShareLink(item: "\(detail.store.name), \(detail.store.area) on District") {
                circle { Image("sdp_ic_share").resizable().frame(width: 24, height: 24) }
            }
            .accessibilityLabel("Share \(detail.store.name)")
            Button { saved.toggle() } label: {
                Image("sdp_ic_bookmark")
                    .resizable()
                    .frame(width: 36, height: 36)
                    .overlay {
                        if saved {
                            Image(systemName: "bookmark.fill").font(.system(size: 14)).foregroundStyle(P.grey50)
                        }
                    }
                    .frame(width: 44, height: 44)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(saved ? "Saved" : "Save store")
            .accessibilityAddTraits(saved ? .isSelected : [])
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.top, R.spacingSpace8)
    }

    /// Figma header button: a 36pt blurred disc with a 24pt glyph, on a 44pt target.
    private func roundButton(_ icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { circle { Image(icon).resizable().frame(width: 24, height: 24) } }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
    }

    private func circle<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(6)
            .background(Color.black.opacity(0.08), in: Circle())
            .background(.ultraThinMaterial, in: Circle())
            .frame(width: 44, height: 44)
            .contentShape(Circle())
    }

    // MARK: Hero

    private var hero: some View {
        Image(detail.hero)
            .resizable()
            .scaledToFill()
            .frame(height: Self.heroHeight)
            .frame(maxWidth: .infinity)
            .clipped()
            .overlay(alignment: .top) {
                LinearGradient(colors: [.black.opacity(0.45), .clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
            }
            .overlay(alignment: .bottomLeading) {
                Text("01/\(String(format: "%02d", detail.store.products.count))")
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, R.spacingSpace4)
                    .background(M.surfaceTransparent, in: Capsule())
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.leading, R.spacingSpace16)
                    .padding(.bottom, Self.heroHeight - 239 - 22)
                    .accessibilityLabel("Photo 1 of \(detail.store.products.count)")
            }
            .overlay(alignment: .bottomTrailing) {
                Button { catalogue = CatalogueRoute(collection: 0) } label: {
                    Image("sdp_ic_gallery")
                        .resizable()
                        .frame(width: 21.5, height: 21.5)
                        .padding(6.75)
                        .background(M.surfaceTransparent, in: Circle())
                        .background(.ultraThinMaterial, in: Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(.trailing, R.spacingSpace12)
                .padding(.bottom, Self.heroHeight - 228 - 40)
                .accessibilityLabel("See all photos")
            }
            .accessibilityHidden(false)
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: 0) {
            identity
                .padding(.top, 26)
            offers
                .padding(.top, 20)
            catalogues
                .id("catalogue")
                .padding(.top, R.spacingSpace24)
            aboutBrand
                .padding(.top, R.spacingSpace24)
            otherStores
                .id("stores")
                .padding(.top, R.spacingSpace32)
                .padding(.bottom, R.spacingSpace48)
        }
        .frame(maxWidth: .infinity)
        .background(M.backgroundPrimary, in: UnevenRoundedRectangle(topLeadingRadius: 16, topTrailingRadius: 16))
        .shadow(color: .black.opacity(0.1), radius: 15, y: -13)
        .overlay(alignment: .top) { logo.offset(y: -(Self.sheetTop - 250)) }
        .padding(.top, -(Self.heroHeight - Self.sheetTop))
    }

    private var logo: some View {
        Group {
            if let logo = detail.logo {
                Color.white
                    .overlay { Image(logo).resizable().scaledToFill().frame(width: 53.318, height: 40).offset(x: 0.0, y: -2.5) }
            } else {
                BrandMark(brand: detail.store.name, mark: detail.store.mark, size: 45)
            }
        }
        .frame(width: 45, height: 45)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .accessibilityHidden(true)
    }

    // MARK: Identity

    private var identity: some View {
        VStack(spacing: R.spacingSpace16) {
            VStack(spacing: R.spacingSpace12) {
                VStack(spacing: R.spacingSpace8) {
                    Text(detail.store.name)
                        .backstageText(.title1)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                        .accessibilityAddTraits(.isHeader)
                    HStack(spacing: 3) {
                        Text(detail.categories.0)
                        if !detail.categories.1.isEmpty {
                            Image("sdp_ic_dot").resizable().frame(width: 4, height: 4)
                            Text(detail.categories.1)
                        }
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textSecondary)
                    .lineLimit(1)
                    Text("\(String(format: "%.1f", detail.store.distance)) kms | 2nd floor, \(detail.mall)\n\(detail.store.area)")
                        .backstageText(.body3)
                        .foregroundStyle(M.textSecondary)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                        .frame(width: 230)
                }
                // Store perks in one row: parking, and that pieces here can be tried on.
                HStack(spacing: R.spacingSpace8) {
                    parkingChip
                    tryOnChip
                }
            }
            quickActions
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private var parkingChip: some View {
        HStack(spacing: 3) {
            Image("sdp_ic_parking").resizable().scaledToFill().frame(width: 14, height: 14).offset(y: -1)
            Text("Free parking available")
                .backstageText(.label3)
                .foregroundStyle(M.textPrimary)
            Image("sdp_ic_chev16").resizable().frame(width: 16, height: 16)
        }
        .padding(.leading, 5)
        .padding(.trailing, 6)
        .padding(.vertical, R.spacingSpace4)
        .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    /// "Virtual try-on available": the parking pill's shape, with a champagne edge and sparkle so
    /// it reads as the try-on feature. Opens the try-on guide.
    private var tryOnChip: some View {
        Button { tryOnGuide = true } label: {
            HStack(spacing: 3) {
                Image("vto_edu_star_small").resizable().renderingMode(.template)
                    .foregroundStyle(Color(rgba: 0xFFEED1FF))
                    .frame(width: 12, height: 12)
                Text("Virtual try-on available")
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                Image("sdp_ic_chev16").resizable().frame(width: 16, height: 16)
            }
            .padding(.leading, 6)
            .padding(.trailing, 6)
            .padding(.vertical, R.spacingSpace4)
            .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color(rgba: 0xFFEED1FF).opacity(0.45), lineWidth: 0.8))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Shows how virtual try-on works")
    }

    private var quickActions: some View {
        HStack(spacing: R.spacingSpace8) {
            actionTile(width: nil, label: "Open now, closes 9:30 PM") {
                VStack(spacing: 2) {
                    Text("Open now").foregroundStyle(P.success)
                    Text("Closes 09.30 PM").foregroundStyle(M.textPrimary)
                }
                .backstageText(.label3)
            }
            actionTile(width: nil, label: "Other stores") {
                Text("Other stores").backstageText(.label3).foregroundStyle(M.textPrimary)
            }
            actionTile(width: 44, label: "Directions") {
                Image("sdp_ic_direction").resizable().frame(width: 18, height: 18)
            }
            actionTile(width: 44, label: "Call the store") {
                Image("sdp_ic_phone").resizable().frame(width: 18, height: 18)
            }
        }
    }

    /// Figma secondary button: white 8% on an 8pt radius with a soft inner bevel.
    /// A nil width shares the row's leftover space, so the row always spans the 16pt margins.
    private func actionTile<Content: View>(width: CGFloat?, label: String, @ViewBuilder content: () -> Content) -> some View {
        Button {} label: {
            content()
                .frame(maxWidth: width ?? .infinity)
                .frame(width: width, height: 40)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(LinearGradient(colors: [.white.opacity(0.04), .black.opacity(0.08)], startPoint: .top, endPoint: .bottom), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel(label)
    }

    // MARK: Offers

    private var offers: some View {
        VStack(spacing: R.spacingSpace16) {
            ZStack(alignment: .topLeading) {
                OffersTabShape()
                    .fill(LinearGradient(colors: [Color(rgba: 0x3B3B3FBA), Color(rgba: 0x13131600)], startPoint: .top, endPoint: .bottom))
                    .overlay {
                        OffersTabShape()
                            .inset(by: 0.5)
                            .stroke(LinearGradient(stops: [.init(color: Color(rgba: 0x8B8B93FF), location: 0.22), .init(color: .white.opacity(0.08), location: 0.68)],
                                                   startPoint: UnitPoint(x: -0.18, y: -0.86), endPoint: UnitPoint(x: 0.6, y: 1.15)), lineWidth: 1)
                    }
                Text("Available Offers")
                    .backstageText(.title4)
                    .foregroundStyle(M.textPrimary)
                    .padding(.leading, 12)
                    .padding(.top, 4)
                VStack(spacing: 0) {
                    inStoreOffer
                        .padding(.top, 32)
                    payViaDistrict
                        .padding(.top, 15)
                    bankOffer(icon: Image("sdp_ic_offer_icon"), title: "Flat 10% OFF upto ₹500", detail: "On bills above ₹1,000")
                        .padding(.top, 12)
                    bankOffer(icon: Image("sdp_bank_hdfc"), iconSize: 18, title: "Flat 10% OFF upto ₹500", detail: "On bills above ₹3,000")
                        .padding(.top, 10)
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 277)

            seeAllOffers
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private var inStoreOffer: some View {
        Button {} label: {
            HStack(spacing: R.spacingSpace12) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    HStack(spacing: R.spacingSpace8) {
                        Text("Buy 3, Get 40% OFF")
                            .backstageText(.title4)
                            .foregroundStyle(M.textWhite)
                        Text("In-store")
                            .backstageText(.label3)
                            .foregroundStyle(M.textOffer)
                            .padding(.horizontal, 7)
                            .frame(height: 17)
                            .background(M.surfaceOfferSecondary, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                    }
                    Text("on spends above ₹10,000")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                }
                Spacer(minLength: 0)
                Image("sdp_ic_offer_chev").resizable().frame(width: 24, height: 24)
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace12)
            .padding(.trailing, -R.spacingSpace8)
            .background(LinearGradient(colors: [M.surfaceSecondary, M.backgroundPrimary], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .buttonStyle(PressableStyle())
    }

    private var payViaDistrict: some View {
        HStack(spacing: 0) {
            Image("sdp_ic_rule_l").resizable().frame(height: 1)
            Text("Get when you pay via District")
                .dropFont("Medium", 12, relativeTo: .caption)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(M.textSecondary)
                .fixedSize()
                .padding(.horizontal, R.spacingSpace8)
                .padding(.vertical, 2)
            Image("sdp_ic_rule_r").resizable().frame(height: 1).scaleEffect(x: -1, y: 1)
        }
        .frame(height: 18)
        .padding(.trailing, 3)
    }

    private func bankOffer(icon: Image, iconSize: CGFloat = 24, title: String, detail: String) -> some View {
        HStack(spacing: R.spacingSpace8) {
            Image("sdp_ic_plus").resizable().frame(width: 24, height: 24)
            Button {} label: {
                HStack(spacing: R.spacingSpace8) {
                    icon.resizable().scaledToFit().frame(width: iconSize, height: iconSize).frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: R.spacingSpace4) {
                        Text(title).backstageText(.label2).foregroundStyle(M.textPrimary)
                        Text(detail).backstageText(.label3).foregroundStyle(M.textSecondary)
                    }
                    Spacer(minLength: 0)
                    Image("sdp_ic_offer_chev").resizable().frame(width: 24, height: 24).padding(.trailing, -6.5)
                }
                .padding(12)
                .background(LinearGradient(colors: [M.surfaceSecondary, M.backgroundSecondary], startPoint: .leading, endPoint: .trailing),
                            in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            }
            .buttonStyle(PressableStyle())
            .accessibilityElement(children: .combine)
        }
    }

    private var seeAllOffers: some View {
        Button {} label: {
            HStack(spacing: R.spacingSpace8) {
                HStack(spacing: -8) {
                    ForEach(["spdp_bank_tide", "spdp_bank_idfc", "spdp_bank_hsbc"], id: \.self) { logo in
                        Image(logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 24, height: 24)
                            .clipShape(RoundedRectangle(cornerRadius: 13.47, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 13.47, style: .continuous).strokeBorder(M.borderIntense, lineWidth: 1.5))
                    }
                }
                HStack(spacing: 2) {
                    Text("See all 10 offers").backstageText(.button3).foregroundStyle(M.textPrimary)
                    Image("sdp_ic_chev_down").resizable().frame(width: 16, height: 16).rotationEffect(.degrees(-90))
                }
            }
            .padding(8)
            .background(M.surfacePrimary, in: Capsule())
            .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: 0.5))
        }
        .buttonStyle(PressableStyle())
    }

    // MARK: Catalogue

    private var catalogues: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text("Catalogue")
                .dropFont("SemiBold", 16, relativeTo: .headline)
                .tracking(-0.16)
                .foregroundStyle(M.textPrimary)
                .frame(height: 24)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: R.spacingSpace24) {
                    ForEach(Array(detail.catalogues.enumerated()), id: \.element.id) { i, c in
                        Button { catalogue = CatalogueRoute(collection: i) } label: {
                            CatalogueCard(catalogue: c, store: detail.store.name, sweepDelay: Double(i) * 1.6)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityHint("Opens the catalogue")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            // Try-on starts from a piece, so it's taught right where the pieces are.
            TryOnCatalogueSteps(piece: detail.catalogues.first?.tiles[3].image ?? "") { tryOnGuide = true }
                .id("tryon")
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace12)
        }
    }

    // MARK: About

    private var aboutBrand: some View {
        VStack(alignment: .leading, spacing: 10.112) {
            Text("About the brand")
                .backstageText(.title3)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Button { withAnimation(.snappy) { readMore.toggle() } } label: {
                (Text(readMore ? detail.about : shortAbout).foregroundStyle(M.textSecondary)
                 + Text(readMore ? " " : " ... ").foregroundStyle(M.textSecondary)
                 + Text(readMore ? "Read less" : "Read more").font(.custom("BeVietnamPro-SemiBold", size: 11.797)).foregroundStyle(P.grey50))
                    .font(.custom("BeVietnamPro-Regular", size: 11.797, relativeTo: .caption))
                    .lineSpacing(6.7)
                    .multilineTextAlignment(.leading)
                    .opacity(0.87)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace16)
    }

    /// The story cut at a word so "... Read more" always fits in three lines.
    private var shortAbout: String {
        let limit = 130
        guard detail.about.count > limit else { return detail.about }
        let cut = detail.about.prefix(limit)
        return String(cut[..<(cut.lastIndex(of: " ") ?? cut.endIndex)])
    }

    // MARK: Other stores

    private var otherStores: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            Text("Other stores in \(detail.mall)")
                .backstageText(.title3)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(alignment: .top, spacing: R.spacingSpace16) {
                    ForEach(detail.nearby) { s in
                        Button { open(s) } label: { NearbyStoreCard(store: s) }
                            .buttonStyle(PressableStyle())
                            .accessibilityElement(children: .combine)
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }

    private func open(_ s: NearbyStore) {
        if let store = StoresData.stores.first(where: { $0.name.caseInsensitiveCompare(s.name) == .orderedSame }) {
            nearby = StoreDetail.of(store)
        }
    }

    // MARK: Pay bill

    /// The foot: a "No cost EMI" pill, then the cashback strip riding on the "Pay bill" card.
    private var payBar: some View {
        VStack(spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace8) {
                Image("sdp_ic_emi").resizable().frame(width: 16, height: 16)
                Text("No cost EMI available above ₹4,000")
                    .dropFont("SemiBold", 12, relativeTo: .caption)
                    .foregroundStyle(M.textWhite)
            }
            .padding(.horizontal, R.spacingSpace8)
            .frame(height: 34)
            .background(P.emiPill, in: Capsule())

            VStack(spacing: 0) {
                cashbackStrip
                Button {} label: {
                    Text("Pay bill")
                        .font(.custom("BeVietnamPro-SemiBold", size: 15, relativeTo: .body))
                        .tracking(-0.2)
                        .foregroundStyle(P.payLabel)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(P.grey50, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                }
                .buttonStyle(PressableStyle())
                .padding(.horizontal, 20)
                .padding(.vertical, R.spacingSpace16)
                .background(M.backgroundPrimary, in: UnevenRoundedRectangle(bottomLeadingRadius: 24, bottomTrailingRadius: 24))
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace12)
        .frame(maxWidth: .infinity)
        .background {
            LinearGradient(stops: [.init(color: M.backgroundPrimary.opacity(0), location: 0.098), .init(color: M.backgroundPrimary, location: 0.984)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    private var cashbackStrip: some View {
        Button {} label: {
            ZStack(alignment: .leading) {
                LinearGradient(colors: [P.purple900, P.purple600], startPoint: .leading, endPoint: .trailing)
                ZStack {
                    Image("sdp_ic_cash_v1").resizable().frame(width: 19.29, height: 21.09).rotationEffect(.degrees(-18.87)).offset(x: 1.2, y: 1.5)
                    Image("sdp_ic_cash_v2").resizable().frame(width: 19.29, height: 21.09).rotationEffect(.degrees(-18.87)).offset(x: 1.4, y: 1.5)
                    Image("sdp_ic_cash_iso").resizable().frame(width: 21.067, height: 19.487).rotationEffect(.degrees(-16.49))
                }
                .frame(width: 26.6, height: 25.46)
                .padding(.leading, 8)
                Text("Get extra 10% cashback on your bill payment")
                    .backstageText(.label2)
                    .foregroundStyle(M.textWhite)
                    .padding(.leading, 38)
                Image("sdp_ic_cash_chev").resizable().frame(width: 8, height: 12)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, 16)
            }
            .frame(height: 34)
            .clipShape(UnevenRoundedRectangle(topLeadingRadius: 24, topTrailingRadius: 24))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Catalogue card

/// Figma "LookBook" card: a 300pt collage (tall left, two stacked right, three across the foot)
/// with the catalogue's name and starting price. The whole card opens the catalogue grid.
private struct CatalogueCard: View {
    let catalogue: StoreCatalogue
    let store: String
    /// Staggers the try-on scan line between cards.
    var sweepDelay: Double = 0

    var body: some View {
        let t = catalogue.tiles
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    tile(t[0], width: 150, height: 200)
                    VStack(spacing: 0) {
                        tile(t[1], width: 150, height: 100)
                        tile(t[2], width: 150, height: 100)
                    }
                }
                HStack(spacing: 0) {
                    tile(t[3], width: 100, height: 100)
                    tile(t[4], width: 100, height: 100)
                    tile(t[5], width: 100, height: 100)
                }
            }
            .frame(width: 300, height: 300)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(P.tileRule, lineWidth: 1))
            .overlay { TryOnCollageSweep(delay: sweepDelay).clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous)) }
            .overlay(alignment: .topLeading) { TryOnReadyTag().padding(10) }

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(catalogue.title)
                        .dropFont("SemiBold", 16, relativeTo: .headline)
                        .tracking(-0.16)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                    Text("Starting from \(rupees(catalogue.startingFrom(at: store)))")
                        .dropFont("Regular", 12, relativeTo: .caption)
                        .foregroundStyle(M.textSecondary)
            }
            .frame(width: 300, alignment: .leading)
        }
        .contentShape(Rectangle())
    }

    private func tile(_ tile: CatalogueTile, width: CGFloat, height: CGFloat) -> some View {
        P.tileFill
                .overlay(alignment: .topLeading) {
                    if let crop = tile.crop {
                        Image(tile.image).resizable().scaledToFill()
                            .frame(width: crop.width, height: crop.height)
                            .clipped()
                            .offset(x: crop.minX, y: crop.minY)
                    } else {
                        Image(tile.image).resizable().scaledToFill().frame(width: width, height: height).clipped()
                    }
                }
                .frame(width: width, height: height)
                .clipped()
                .overlay(Rectangle().strokeBorder(P.tileRule, lineWidth: 1))
    }
}

// MARK: - Other stores

/// Figma "Movie Card" for a store in the mall: photo, the offer strip, name and distance.
private struct NearbyStoreCard: View {
    let store: NearbyStore

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(width: 183, height: 183)
                .overlay(alignment: .topLeading) {
                    if let crop = store.crop {
                        Image(store.image).resizable().scaledToFill()
                            .frame(width: crop.width, height: crop.height)
                            .offset(x: crop.minX, y: crop.minY)
                    } else {
                        Image(store.image).resizable().scaledToFill().frame(width: 183, height: 183)
                    }
                }
                .clipped()
                .overlay(Rectangle().strokeBorder(P.imageRule, lineWidth: 1))
            HStack(spacing: R.spacingSpace4) {
                Image("sdp_ic_store_offer").resizable().frame(width: 15.627, height: 15.627)
                Text("Flat 10% OFF + 3 more")
                    .backstageText(.label3)
                    .foregroundStyle(M.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, R.spacingSpace4)
            .background(P.offerStrip)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(store.name)
                    .dropFont("SemiBold", 16, relativeTo: .headline)
                    .tracking(-0.16)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Text("\(store.area) • \(store.distance)")
                    .backstageText(.body3)
                    .foregroundStyle(P.grey300)
                    .lineLimit(1)
            }
            .padding(8)
        }
        .frame(width: 183)
        .background(M.backgroundPrimary)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .shadow(color: .black.opacity(0.1), radius: 17.7, y: 4)
    }
}

// MARK: - Offers card

/// The Figma "Union" outline of the offers card: a folder tab holding "Available Offers" at the
/// top left, the body below. The tab keeps its size; the body stretches to the card's width.
private struct OffersTabShape: InsettableShape {
    var inset: CGFloat = 0

    func inset(by amount: CGFloat) -> OffersTabShape { OffersTabShape(inset: inset + amount) }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset, dy: inset)
        let x0 = r.minX, y0 = r.minY, w = r.maxX, h = r.maxY
        return Path { p in
            p.move(to: CGPoint(x: x0 + 137.506, y: y0 + 12.905))
            p.addCurve(to: CGPoint(x: x0 + 146.463, y: y0 + 16.919), control1: CGPoint(x: x0 + 139.783, y: y0 + 15.459), control2: CGPoint(x: x0 + 143.042, y: y0 + 16.919))
            p.addLine(to: CGPoint(x: w - 12, y: y0 + 16.919))
            p.addCurve(to: CGPoint(x: w, y: y0 + 28.919), control1: CGPoint(x: w - 5.373, y: y0 + 16.919), control2: CGPoint(x: w, y: y0 + 22.292))
            p.addLine(to: CGPoint(x: w, y: h - 16))
            p.addCurve(to: CGPoint(x: w - 16, y: h), control1: CGPoint(x: w, y: h - 7.163), control2: CGPoint(x: w - 7.163, y: h))
            p.addLine(to: CGPoint(x: x0 + 16, y: h))
            p.addCurve(to: CGPoint(x: x0, y: h - 16), control1: CGPoint(x: x0 + 7.163, y: h), control2: CGPoint(x: x0, y: h - 7.163))
            p.addLine(to: CGPoint(x: x0, y: y0 + 12))
            p.addCurve(to: CGPoint(x: x0 + 12, y: y0), control1: CGPoint(x: x0, y: y0 + 5.373), control2: CGPoint(x: x0 + 5.373, y: y0))
            p.addLine(to: CGPoint(x: x0 + 120.622, y: y0))
            p.addCurve(to: CGPoint(x: x0 + 129.579, y: y0 + 4.014), control1: CGPoint(x: x0 + 124.043, y: y0), control2: CGPoint(x: x0 + 127.302, y: y0 + 1.460))
            p.closeSubpath()
        }
    }
}

// MARK: - Catalogue

/// Opens the try-on flow at a step.
struct TryOnRoute: Identifiable {
    let id = UUID()
    let step: TryOnFlowView.Step
}

/// Which collection the catalogue grid opens on.
struct CatalogueRoute: Identifiable {
    var id: Int { collection }
    let collection: Int
    /// Arrived from the try-on guide: point at TryOn! on the first piece opened.
    var tryOnHint = false
}

/// Where the full-screen viewer opens: a collection and a piece in it.
private struct ViewerRoute: Identifiable {
    var id: String { "\(collection)-\(index)" }
    let collection: Int
    let index: Int
}

/// The store's catalogue (Figma "No vibe section", 9388:4321): the collections as chips over two
/// rows, then the chosen collection's pieces three to a row. A piece opens the full-screen viewer.
struct CatalogueGridView: View {
    let detail: StoreDetail
    @State var selected: Int
    var tryOnHint = false
    @State private var viewer: ViewerRoute?
    @State private var hintUsed = false
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var collections: [StoreCatalogue] { detail.collections }
    private var pieces: [CatalogueTile] { collections[min(selected, collections.count - 1)].tiles }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: R.spacingSpace12), count: 3), spacing: R.spacingSpace12) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { i, tile in
                    let piece = StoreProduct.from(image: tile.image, store: detail.store.name)
                    Button { viewer = ViewerRoute(collection: selected, index: i) } label: {
                        Color.clear
                            .frame(height: 100)
                            .overlay { Image(tile.image).resizable().scaledToFill() }
                            .background(Color(rgba: 0xEBEBEBFF))
                            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                            .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .accessibilityLabel("\(piece.name), \(rupees(piece.price))")
                    .accessibilityHint("Opens the piece full screen")
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace24)
            .padding(.bottom, 160)
            .id(selected)
            .transition(.opacity)
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                CataloguePageHeader(title: "Catalogue", store: detail.store.name) { dismiss() }
                chips
            }
            .background(SDPPalette.pageFill)
        }
        .overlay(alignment: .bottom) { CatalogueFootFade().allowsHitTesting(false) }
        .background(SDPPalette.pageFill.ignoresSafeArea())
        .readerCover(item: $viewer) { route in
            CatalogueViewer(collection: collections[route.collection], store: detail.store.name, start: route.index,
                            tryOnHint: tryOnHint && !hintUsed)
                .onAppear { hintUsed = true }
        }
        .sensoryFeedback(.selection, trigger: selected)
        #if DEBUG
        // `-openViewer <n>` opens the full-screen viewer on that piece.
        .task {
            guard !DebugLaunch.viewerUsed else { return }
            DebugLaunch.viewerUsed = true
            let args = ProcessInfo.processInfo.arguments
            if let i = args.firstIndex(of: "-openViewer"), i + 1 < args.count, let n = Int(args[i + 1]) {
                try? await Task.sleep(for: .seconds(0.6))
                viewer = ViewerRoute(collection: selected, index: min(n, pieces.count - 1))
            }
        }
        #endif
    }

    /// Collections laid over two rows that scroll sideways together.
    private var chips: some View {
        let half = Int((Double(collections.count) / 2).rounded(.up))
        let rows = [Array(collections.indices.prefix(half)), Array(collections.indices.dropFirst(half))].filter { !$0.isEmpty }
        return ScrollView(.horizontal) {
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                ForEach(rows, id: \.self) { row in
                    HStack(spacing: R.spacingSpace8) {
                        ForEach(row, id: \.self) { i in chip(i) }
                    }
                }
            }
        }
        .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
        .scrollIndicators(.hidden)
    }

    private func chip(_ i: Int) -> some View {
        let on = i == selected
        return Button {
            withAnimation(reduceMotion ? nil : .snappy) { selected = i }
        } label: {
            Text(collections[i].title)
                .backstageText(on ? .body3 : .label2)
                .foregroundStyle(on ? SDPPalette.grey50 : M.textSecondary)
                .lineLimit(2)
                .padding(.horizontal, on ? R.spacingSpace8 : R.spacingSpace12)
                .frame(height: 40)
                .background(on ? Color.black.opacity(0.16) : .clear, in: Capsule())
                .overlay(Capsule().strokeBorder(on ? Color(rgba: 0xF1F1F2FF) : M.borderModerate, lineWidth: R.stroke1Px))
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
    }
}

/// The catalogue screens' header: back, then the title over the store's name.
private struct CataloguePageHeader: View {
    let title: String
    let store: String
    var closeGlyph = "arrow.left"
    let back: () -> Void

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: closeGlyph, label: closeGlyph == "chevron.down" ? "Close" : "Back", action: back)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(title)
                    .backstageText(.title2)
                    .foregroundStyle(SDPPalette.grey50)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(store)
                    .backstageText(.label2)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
    }
}

/// Figma 237pt fade into surface/primary at the foot of the catalogue screens.
private struct CatalogueFootFade: View {
    var body: some View {
        LinearGradient(stops: [.init(color: Color(rgba: 0x1E1E2000), location: 0.067), .init(color: M.surfacePrimary, location: 0.902)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 237)
            .ignoresSafeArea(edges: .bottom)
    }
}

/// One collection full screen (Figma "CATALOUGE", 9375:4199, without the Vibe switch): the piece on
/// a large card with arrows either side, its name and price, a "3/32" pager and a thumbnail strip.
/// Swipe the card or tap the arrows to move; tap the card for the piece's product page.
struct CatalogueViewer: View {
    let collection: StoreCatalogue
    let store: String
    @State private var index: Int
    @State private var product: StoreProduct?
    @State private var tryOn: TryOnRoute?
    @State private var onboarding = false
    @State private var pickingPhoto = false
    @State private var photoItem: PhotosPickerItem?
    @State private var waiting: StoreProduct?
    @State private var coach: Bool
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(collection: StoreCatalogue, store: String, start: Int, tryOnHint: Bool = false) {
        self.collection = collection
        self.store = store
        _index = State(initialValue: start)
        _coach = State(initialValue: tryOnHint)
    }

    private var pieces: [StoreProduct] { collection.products(at: store) }
    private var current: StoreProduct { pieces[index] }

    var body: some View {
        VStack(spacing: 0) {
            CataloguePageHeader(title: collection.title, store: store, closeGlyph: "chevron.down") { dismiss() }
            Spacer(minLength: R.spacingSpace16)
            stage
            Spacer(minLength: R.spacingSpace16)
            pager
                .padding(.bottom, R.spacingSpace16)
            thumbnails
                .padding(.bottom, R.spacingSpace24)
        }
        .background(alignment: .bottom) { CatalogueFootFade() }
        .background(SDPPalette.pageFill.ignoresSafeArea())
        .readerCover(item: $product) { StoreProductView(product: $0) }
        .fullScreenCover(item: $tryOn) { TryOnFlowView(step: $0.step) }
        .sheet(isPresented: $onboarding) {
            TryOnOnboardingSheet {
                onboarding = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) { pickingPhoto = true }
            }
        }
        .photosPicker(isPresented: $pickingPhoto, selection: $photoItem, matching: .images)
        .onChange(of: photoItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    TryOnStudio.shared.photo = image
                }
                TryOnStudio.shared.hasPhoto = true
                photoItem = nil
                if let piece = waiting { tryOn = TryOnRoute(step: .styling(piece)) }
                waiting = nil
            }
        }
        .sensoryFeedback(.selection, trigger: index)
        #if DEBUG
        // `-vtoTap` taps TryOn! on the open piece; `-vtoCloset` opens the closet.
        .task {
            let args = ProcessInfo.processInfo.arguments
            try? await Task.sleep(for: .seconds(1))
            if args.contains("-vtoTap") { startTryOn(current) }
            if args.contains("-vtoCloset") { tryOn = TryOnRoute(step: .closet) }
            // `-vtoLooked` gives the open piece a look a moment later, to see the pill turn.
            if args.contains("-vtoLooked") {
                try? await Task.sleep(for: .seconds(2.5))
                _ = TryOnStudio.shared.makeLook(of: current)
            }
        }
        #endif
        .task {
            // The tip steps aside on its own after a while.
            guard coach else { return }
            try? await Task.sleep(for: .seconds(6))
            withAnimation(.snappy) { coach = false }
        }
    }

    /// The piece edge to edge (Figma "catalogue", 23753:81485), swiped sideways, with TryOn! at its
    /// bottom-left; then the name. Tapping the photo opens the product page.
    private var stage: some View {
        VStack(spacing: R.spacingSpace32) {
            TabView(selection: $index) {
                ForEach(Array(pieces.enumerated()), id: \.offset) { i, piece in
                    Button { product = piece } label: {
                        Color(rgba: 0xEBEBEBFF)
                            .overlay { Image(piece.image).resizable().scaledToFill() }
                            .clipped()
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(piece.name), \(rupees(piece.price))")
                    .accessibilityHint("Opens the product")
                    // Try-on starts here, on the piece itself.
                    .overlay(alignment: .bottomLeading) {
                        TryOnPill(viewLook: TryOnStudio.shared.look(for: piece) != nil,
                                  lookImage: TryOnStudio.shared.look(for: piece)?.image) { startTryOn(piece) }
                            .modifier(TryOnCoachMark(active: coach && i == index) { withAnimation(.snappy) { coach = false } })
                            .padding(.leading, R.spacingSpace12)
                            .padding(.bottom, R.spacingSpace12)
                    }
                    .tag(i)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .frame(height: 390)
            Text(current.name)
                .dropFont("SemiBold", 16, relativeTo: .headline)
                .tracking(-0.16)
                .foregroundStyle(SDPPalette.grey50)
                .lineLimit(1)
                .padding(.horizontal, R.spacingSpace16)
                .contentTransition(.opacity)
                .animation(.snappy, value: index)
        }
    }

    /// A piece with a look opens it; otherwise a first-timer meets the onboarding sheet and adds a
    /// photo, and a returning user goes straight to styling.
    private func startTryOn(_ piece: StoreProduct) {
        withAnimation(.snappy) { coach = false }
        let studio = TryOnStudio.shared
        if let look = studio.look(for: piece) {
            tryOn = TryOnRoute(step: .result(look, .catalogue))
        } else if studio.hasPhoto {
            tryOn = TryOnRoute(step: .styling(piece))
        } else {
            waiting = piece
            onboarding = true
        }
    }

    /// "‹ 3/32 ›".
    private var pager: some View {
        HStack(spacing: R.spacingSpace12) {
            Button { step(-1) } label: {
                Image("sdp_ic_pager_prev").resizable().frame(width: 24, height: 24).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(index == 0)
            .accessibilityLabel("Previous piece")
            Text("\(index + 1)/\(pieces.count)")
                .backstageText(.body2)
                .foregroundStyle(M.textPrimary)
                .monospacedDigit()
                .contentTransition(.numericText())
            Button { step(1) } label: {
                Image("sdp_ic_pager_next").resizable().frame(width: 24, height: 24).frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(index == pieces.count - 1)
            .accessibilityLabel("Next piece")
        }
    }

    /// Every piece as a 72pt thumbnail under a dark veil; the current one is 76pt, clear and
    /// outlined, and the strip keeps it centred.
    private var thumbnails: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(Array(pieces.enumerated()), id: \.offset) { i, piece in
                        let on = i == index
                        Button { withAnimation(reduceMotion ? nil : .snappy) { index = i } } label: {
                            Color(rgba: 0xEBEBEBFF)
                                .overlay { Image(piece.image).resizable().scaledToFill() }
                                .overlay { if !on { Color(rgba: 0x1C1C1C66) } }
                                .frame(width: on ? 76 : 72, height: on ? 76 : 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                .overlay {
                                    if on { RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(SDPPalette.grey50, lineWidth: 1) }
                                }
                        }
                        .buttonStyle(.plain)
                        .id(i)
                        .accessibilityLabel(piece.name)
                        .accessibilityAddTraits(on ? [.isButton, .isSelected] : .isButton)
                    }
                }
                .frame(height: 76)
            }
            .scrollIndicators(.hidden)
            .onAppear { proxy.scrollTo(index, anchor: .center) }
            .onChange(of: index) { _, i in
                withAnimation(reduceMotion ? nil : .snappy) { proxy.scrollTo(i, anchor: .center) }
            }
        }
    }

    private func step(_ by: Int) {
        let next = index + by
        guard pieces.indices.contains(next) else { return }
        withAnimation(reduceMotion ? nil : .snappy) { index = next }
    }
}
