import SwiftUI
import ImageIO

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

/// Figma values the Backstage tokens don't carry yet (file "Homepage and Search", PDP 8648:10524).
private enum StorePDPPalette {
    static let success = Color(rgba: 0x58E487FF)          // color/text/success
    static let disabled = Color(rgba: 0x545459FF)         // color/text/disabled
    static let grey50 = Color(rgba: 0xFAFAFAFF)           // colors/neutral-grey/50
    static let hotGold = Color(rgba: 0xB8A91EFF)          // colors/yellow/600
    static let offerLeading = Color(rgba: 0x05101EFF)
    static let offerTrailing = Color(rgba: 0x101113FF)
    static let chipTop = Color(rgba: 0x0B1524FF)
    static let chipFoot = Color(rgba: 0x0E2442FF)
    static let rowFill = Color(rgba: 0x19191CFF)
    static let logoRing = Color(rgba: 0x1E1E20FF)
}

private typealias P = StorePDPPalette

// MARK: - Model

/// A piece from a store's rail on the Stores tab, with what its product page needs. The catalogue
/// is illustrative until live store inventory is wired in.
struct StoreProduct: Identifiable, Hashable {
    enum Kind { case apparel, footwear }

    var id: String { image }
    let image: String
    let name: String
    let brand: String
    let store: String
    let kind: Kind
    let price: Int
    let colour: String
    var hot = false

    var mrp: Int { Int((Double(price) * 1.12 / 100).rounded()) * 100 - 1 }
    /// The best price with District and bank offers, as on the "Get it at" card.
    var bestPrice: Int { price - saveExtra }
    var saveExtra: Int { Int((Double(price) * 0.06 / 10).rounded()) * 10 - 1 }
    var reserveNow: Int { Int((Double(price) * 0.25).rounded()) }

    var tagline: String {
        kind == .footwear
            ? "From \(brand)'s new season: a light, everyday pair with grip that holds up from the office to the weekend."
            : "From \(brand)'s new season, picked up in store the same day. Try it on at the counter before you pay the rest."
    }

    var about: String {
        kind == .footwear
            ? "Built on a cushioned midsole with a breathable upper and a rubber outsole that grips on wet tiles. True to size; go half a size up if you're between sizes."
            : "Cut for an easy fit with room to layer. Soft on the skin, holds its shape wash after wash, and finished in \(brand)'s signature details."
    }

    var sizes: [String] { kind == .footwear ? ["3", "4", "5", "6", "7", "8", "9", "10"] : ["XS", "S", "M", "L", "XL", "XXL"] }
    var soldOut: Set<String> { kind == .footwear ? ["8"] : ["XXL"] }
    var sizeHeading: String { kind == .footwear ? "Available size (UK)" : "Available size" }

    var highlights: [(String, String)] {
        kind == .footwear
            ? [("Material", "Synthetic"), ("Sole", "Rubber"), ("Weight", "280g"), ("Fit", "True"), ("Closure", "Laces")]
            : [("Material", "Cotton"), ("Fit", "Relaxed"), ("Care", "Machine"), ("Origin", "India"), ("Length", "Regular")]
    }

    var details: [(String, String)] {
        [("Brand", brand), ("Colour", colour), ("Category", kind == .footwear ? "Footwear" : "Apparel"), ("Article code", String(image.hashValue.magnitude % 900_000 + 100_000))]
    }

    var keyInformation: [(String, String)] {
        [("Sold by", "\(store) store"), ("Pick-up", "Same day, within 2 hours"), ("Returns", "7 days at the store"), ("Reserve", "Pay 25% now, the rest at pick-up")]
    }

    /// The gallery tiles, cut from the product photo until each piece has its own shoot.
    var shots: [StoreShot] {
        [StoreShot(image: image, zoom: 1, anchor: .center),
         StoreShot(image: image, zoom: 1.7, anchor: .top),
         StoreShot(image: image, zoom: 2.2, anchor: .center),
         StoreShot(image: image, zoom: 2.2, anchor: .bottom),
         StoreShot(image: image, zoom: 1.4, anchor: .bottom)]
    }

    /// The piece behind a photo on a store's rail; unknown photos get a plain listing.
    static func from(image: String, store: String) -> StoreProduct {
        if let entry = catalogue[image] {
            return StoreProduct(image: image, name: entry.name, brand: store, store: store, kind: entry.kind,
                                price: entry.price, colour: entry.colour, hot: entry.hot)
        }
        return StoreProduct(image: image, name: "New in at \(store)", brand: store, store: store, kind: .apparel, price: 2999, colour: "As shown")
    }

    private static let catalogue: [String: (name: String, kind: Kind, price: Int, colour: String, hot: Bool)] = [
        "rack_adidas_popper": ("Adibreak popper track pants", .apparel, 5999, "Cream & gold", true),
        "rack_adidas_track": ("Fleece jogger set", .apparel, 6999, "Bold gold", false),
        "plan_active_1": ("Retro high-top sneakers", .footwear, 9999, "Red & blue", true),
        "plan_active_2": ("Essentials fleece hoodie", .apparel, 4599, "Grey heather", false),
        "plan_active_3": ("Knit running shoes", .footwear, 12999, "Solar red", false),
        "rack_hm_overcoat": ("Wool-blend overcoat", .apparel, 7999, "Rust", true),
        "staple_white_tee_1": ("Printed graphic tee", .apparel, 799, "White", false),
        "palette_slate-noir_2": ("Relaxed sweatshirt", .apparel, 1999, "Black", false),
        "staple_blazer_2": ("Checked two-piece suit", .apparel, 12999, "Slate check", false),
        "rack_zara_dress": ("Fit-and-flare mini dress", .apparel, 3990, "Chocolate", true),
        "rack_zara_blazer": ("Oversized blazer suit", .apparel, 7990, "Ecru", false),
        "plan_office_1": ("Turtleneck & plaid skirt set", .apparel, 4590, "Black", false),
        "plan_office_3": ("Sheer embroidered blouse", .apparel, 2990, "Black", false),
        "rack_nicobar_kaftan": ("Embroidered cotton kaftan", .apparel, 6450, "Mustard", true),
        "plan_diwali_1": ("Silk saree with zari border", .apparel, 14500, "Plum & gold", false),
        "plan_diwali_2": ("Banarasi silk saree", .apparel, 16900, "Coral & gold", false),
        "plan_wedding_1": ("Tulle evening gown", .apparel, 18900, "Wine", false),
        "plan_wedding_3": ("Tiered maxi dress", .apparel, 7450, "Teal", false),
        "photo_rose_2": ("Satin bomber jacket", .apparel, 5450, "Rose", false),
        "rack_snitch_biker": ("Leather biker jacket", .apparel, 3999, "Black", true),
        "staple_denim_1": ("Classic denim jacket", .apparel, 2299, "Mid blue", false),
        "palette_midnight-olive_3": ("Leather jacket over oxford shirt", .apparel, 4499, "Tan", false),
        "staple_blazer_3": ("Unstructured blazer", .apparel, 3499, "Camel", false),
        "rack_bonkers_patchwork": ("Patchwork denim co-ord", .apparel, 4999, "Multicolour", true),
        "rack_bonkers_jeans": ("Distressed patch jeans", .apparel, 2799, "Dark wash", false),
        "staple_white_tee_3": ("Boxy logo tee", .apparel, 1299, "White", false),
        "palette_butter-denim_3": ("Graphic tee & joggers", .apparel, 2499, "Navy & grey", false),
        "staple_denim_2": ("Cropped denim jacket", .apparel, 2599, "Light wash", false),
        "rack_blu_trucker": ("Denim trucker jacket", .apparel, 3299, "Indigo", false),
        // The adidas store page's catalogues (Figma "SDP").
        "sdp_cat_c1_big": ("Hooded parka with faux-fur trim", .apparel, 6999, "Sage", true),
        "sdp_cat_c1_tr": ("Belted longline puffer", .apparel, 8999, "Black", false),
        "sdp_cat_c1_mr": ("Cropped puffer jacket", .apparel, 4999, "Black", false),
        "sdp_cat_c1_b1": ("Hooded puffer jacket", .apparel, 5499, "Rust", false),
        "sdp_cat_c1_b2": ("Quilted parka", .apparel, 6499, "Olive", false),
        "sdp_cat_c1_b3": ("Classic denim jacket", .apparel, 2999, "Mid blue", false),
        "sdp_cat_c2_big": ("Button-front denim dress", .apparel, 2499, "Light wash", true),
        "sdp_cat_c2_tr": ("Floral wrap mini dress", .apparel, 2299, "Peach", false),
        "sdp_cat_c2_mr": ("Belted blanket-stitch jacket", .apparel, 3999, "Ecru", false),
        "sdp_cat_c2_b1": ("Twist-front midi dress", .apparel, 2799, "Berry ombré", false),
        "sdp_cat_c2_b2": ("Puff-sleeve floral dress", .apparel, 1999, "Blush", false),
        "sdp_cat_c2_b3": ("Tiered smock dress", .apparel, 2199, "White", false),
    ]
}

/// One gallery tile: the photo at a zoom, anchored where the detail is.
struct StoreShot: Hashable {
    let image: String
    let zoom: CGFloat
    let anchor: UnitPoint

    static func == (a: StoreShot, b: StoreShot) -> Bool { a.image == b.image && a.zoom == b.zoom && a.anchor == b.anchor }
    func hash(into h: inout Hasher) { h.combine(image); h.combine(zoom) }
}

private struct StoreShotImage: View {
    let shot: StoreShot

    var body: some View {
        Color.clear
            .overlay {
                Image(shot.image)
                    .resizable()
                    .scaledToFill()
                    .scaleEffect(shot.zoom, anchor: shot.anchor)
            }
            .clipped()
    }
}

// MARK: - Product page

/// The Stores product page (Figma "PDP (non store specific)", 8648:10524): a bento gallery, the
/// piece and its price, the "Get it at" offer card, colour and size, the pick-up store, highlights,
/// all details, and "Pay 25% to reserve" in a floating glass bar.
struct StoreProductView: View {
    let product: StoreProduct
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var size: String?
    @State private var readMore = false
    @State private var open: Set<String> = []
    @State private var pickupStore: StoreBranch?
    @State private var choosingStore = false
    @State private var reserved = false
    @State private var gallery: GalleryStart?
    @State private var nudge = 0

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: R.spacingSpace24) {
                    VStack(alignment: .leading, spacing: R.spacingSpace12) {
                        galleryRow
                        intro
                    }
                    StoreOfferCard(product: product)
                        .padding(.top, R.spacingSpace4)
                    colours
                    sizes.id("sizes")
                    pickupRow
                    highlights
                    allDetails
                }
                .padding(.horizontal, R.spacingSpace16)
                .padding(.top, R.spacingSpace20)
                .padding(.bottom, 150)
            }
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) { header }
            .overlay(alignment: .bottom) { actionBar(proxy) }
            #if DEBUG
            // `-storePDPScroll` opens the page scrolled down to the sizes.
            .task {
                guard ProcessInfo.processInfo.arguments.contains("-storePDPScroll") else { return }
                try? await Task.sleep(for: .seconds(0.6))
                proxy.scrollTo("sizes", anchor: .top)
            }
            #endif
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $choosingStore) {
            StorePickupSheet(product: product, selected: $pickupStore)
        }
        .sheet(isPresented: $reserved) {
            StoreReservedSheet(product: product, size: size ?? "", store: pickupStore)
        }
        .fullScreenCover(item: $gallery) { start in
            StoreGalleryView(shots: product.shots, start: start.id)
        }
        .sensoryFeedback(.selection, trigger: size)
        .sensoryFeedback(.warning, trigger: nudge)
    }

    // MARK: Header

    /// Back, the brand, share: the Figma navigation bar over the page.
    private var header: some View {
        HStack {
            GlassIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
            Spacer(minLength: R.spacingSpace8)
            Text(product.brand.uppercased())
                .backstageText(.title4)
                .foregroundStyle(M.textSecondary)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            Spacer(minLength: R.spacingSpace8)
            ShareLink(item: "\(product.name) at \(product.store) on District") {
                Image("spdp_ic_share")
                    .resizable()
                    .frame(width: 23.75, height: 23.75)
                    .frame(width: 44, height: 44)
                    .liquidGlass(in: Circle(), interactive: true, clear: true)
            }
            .accessibilityLabel("Share \(product.name)")
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
        .background {
            LinearGradient(colors: [M.backgroundPrimary, M.backgroundPrimary.opacity(0)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: Gallery

    /// Figma "4:3 video case": a wide photo, a square, then two small squares over a "View
    /// gallery" tile, in a row that bleeds off the right edge.
    private var galleryRow: some View {
        let shots = product.shots
        return ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace12) {
                tile(shots[0], index: 0, width: 215, height: 179, radius: 16)
                tile(shots[1], index: 1, width: 178, height: 178, radius: 16)
                VStack(spacing: R.spacingSpace12) {
                    HStack(spacing: 6.6) {
                        tile(shots[2], index: 2, width: 100, height: 100, radius: 16, stroke: 0.548)
                        tile(shots[3], index: 3, width: 99.4, height: 100, radius: 16, stroke: 0.548)
                    }
                    viewGalleryTile(shots[4])
                }
            }
            .padding(.trailing, 32)
        }
        .scrollIndicators(.hidden)
        .scrollClipDisabled()
        .frame(height: 179)
    }

    private func tile(_ shot: StoreShot, index: Int, width: CGFloat, height: CGFloat, radius: CGFloat, stroke: CGFloat = 1) -> some View {
        Button { gallery = GalleryStart(id: index) } label: {
            StoreShotImage(shot: shot)
                .frame(width: width, height: height)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: stroke))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("Photo \(index + 1) of \(product.shots.count)")
        .accessibilityHint("Opens the gallery")
    }

    /// The last tile: a photo under the Figma's frosted veil, with "View gallery".
    private func viewGalleryTile(_ shot: StoreShot) -> some View {
        Button { gallery = GalleryStart(id: 0) } label: {
            ZStack {
                Color.white
                StoreShotImage(shot: shot)
                    .frame(width: 216.234, height: 233.193)
                    .position(x: -9.31 + 216.234 / 2, y: -110.69 + 233.193 / 2)
                Image("spdp_gallery_veil")
                    .resizable()
                    .frame(width: 1210.51, height: 530.214)
                    .rotationEffect(.degrees(20.1))
                    .position(x: -513.34 + 1277.474 / 2, y: -516.03 + 872.394 / 2)
                HStack(spacing: 1) {
                    Text("View gallery")
                        .font(.custom("BeVietnamPro-SemiBold", size: 14, relativeTo: .subheadline))
                        .foregroundStyle(Color(rgba: 0xF7F7F7DB))
                    Image("spdp_ic_gallery_chevron").resizable().frame(width: 17.58, height: 17.58)
                }
            }
            .frame(width: 206, height: 67)
            .clipShape(RoundedRectangle(cornerRadius: 12.109, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12.109, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.53))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("View gallery")
    }

    // MARK: Intro

    private var intro: some View {
        VStack(alignment: .leading, spacing: 5) {
            if product.hot { HotThisWeekTag() }
            VStack(alignment: .leading, spacing: 6) {
                Text(product.name)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                Text(product.tagline)
                    .backstageText(.body3)
                    .foregroundStyle(M.textTertiary)
                    .lineLimit(2)
                HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
                    Text(rupees(product.price))
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                    Text(rupees(product.mrp))
                        .dropFont("Medium", 12)
                        .strikethrough()
                        .foregroundStyle(M.textSecondary)
                        .opacity(0.6)
                        .accessibilityLabel("was \(rupees(product.mrp))")
                    Text("Save \(rupees(product.mrp - product.price))")
                        .backstageText(.label2)
                        .foregroundStyle(P.success)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(P.success.opacity(0.1), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
                }
            }
        }
    }

    // MARK: Choices

    /// The Figma caps label: Label 2 face, uppercase, 1.2 tracking.
    private func capsLabel(_ text: String) -> some View {
        Text(text)
            .dropFont("Medium", 12, relativeTo: .subheadline)
            .tracking(1.2)
            .textCase(.uppercase)
    }

    private var colours: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            (Text("Colour").foregroundStyle(M.textPrimary) + Text(" • \(product.colour)").foregroundStyle(M.textSecondary))
                .dropFont("Medium", 12, relativeTo: .subheadline)
                .tracking(1.2)
                .textCase(.uppercase)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            // One colourway per piece for now, shown selected.
            Image(product.image)
                .resizable()
                .scaledToFill()
                .frame(width: 74.317, height: 74.317)
                .background(Color.white)
                .clipShape(RoundedRectangle(cornerRadius: 9.8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 9.8, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.817))
                .padding(3.267)
                .overlay(RoundedRectangle(cornerRadius: 13.067, style: .continuous).strokeBorder(M.borderSelection, lineWidth: 0.817))
                .accessibilityLabel("\(product.colour), selected")
        }
    }

    private var sizes: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack(spacing: R.spacingSpace8) {
                capsLabel(product.sizeHeading)
                    .foregroundStyle(M.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityAddTraits(.isHeader)
                Button("Size chart") {}
                    .buttonStyle(BackstageTextButtonStyle())
                    .underline()
            }
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(product.sizes, id: \.self) { s in sizeButton(s) }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
            .modifier(StoreShake(trigger: nudge))
            if nudge > 0 && size == nil {
                Label("Pick a size to continue", systemImage: "exclamationmark.circle")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
                    .transition(.opacity)
            }
        }
    }

    private func sizeButton(_ s: String) -> some View {
        let on = s == size
        let out = product.soldOut.contains(s)
        return Button { withAnimation(.snappy) { size = s } } label: {
            Text(s)
                .dropFont("Medium", 14)
                .tracking(-0.24)
                .foregroundStyle(out ? P.disabled : P.grey50)
                .frame(width: 55, height: 44)
                .background(on ? M.surfaceSecondary : .clear, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(on ? M.borderSelection : (out ? M.borderSubtle : M.borderModerate), lineWidth: R.stroke1Px))
                .overlay {
                    if out {
                        Image("spdp_size_cross").resizable().frame(width: 35, height: 37.5).offset(x: 1, y: -0.25)
                    }
                }
        }
        .buttonStyle(.plain)
        .disabled(out)
        .accessibilityLabel(out ? "Size \(s), sold out" : "Size \(s)")
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    // MARK: Pick-up

    private var pickupRow: some View {
        Button { choosingStore = true } label: {
            HStack(spacing: R.spacingSpace8) {
                Image("spdp_ic_store").resizable().frame(width: 16, height: 16)
                VStack(alignment: .leading, spacing: 2) {
                    Text(pickupStore.map { "Pick up at \($0.name)" } ?? "Select pick-up store")
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                    if let store = pickupStore {
                        Text("\(store.distance) • \(store.area)")
                            .backstageText(.body3)
                            .foregroundStyle(M.textTertiary)
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                Image("spdp_ic_chevron").resizable().frame(width: 24, height: 24)
            }
            .padding(10)
            .background(P.rowFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
            .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .accessibilityHint("Choose the store to pick this up from")
    }

    // MARK: Highlights

    /// Figma highlights: small tiles, the label on a tinted cap above the value.
    private var highlights: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            capsLabel("Highlights").foregroundStyle(M.textSecondary).accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(Array(product.highlights.enumerated()), id: \.offset) { i, h in
                        VStack(spacing: 0) {
                            Text(h.0)
                                .backstageText(.label2)
                                .foregroundStyle(M.textTertiary)
                                .frame(maxWidth: .infinity)
                                .padding(R.spacingSpace4)
                                .background(M.surfaceTransparent)
                            Text(h.1)
                                .backstageText(.label2)
                                .foregroundStyle(M.textPrimary)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity)
                                .padding(R.spacingSpace4)
                        }
                        .frame(width: i == 0 ? 76 : 68)
                        .background(M.surfaceTransparent)
                        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                        .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                        .accessibilityElement(children: .combine)
                    }
                }
            }
            .scrollIndicators(.hidden)
            .scrollClipDisabled()
        }
    }

    // MARK: All details

    private var allDetails: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            capsLabel("All details").foregroundStyle(M.textSecondary).accessibilityAddTraits(.isHeader)
            Button { withAnimation(.snappy) { readMore.toggle() } } label: {
                (Text(product.about + " ").foregroundStyle(M.textTertiary)
                 + Text(readMore ? "Read less" : "Read more").foregroundStyle(M.textPrimary))
                    .backstageText(.body3)
                    .lineLimit(readMore ? nil : 3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            accordion("Product details", rows: product.details)
            accordion("Key information", rows: product.keyInformation)
        }
    }

    private func accordion(_ title: String, rows: [(String, String)]) -> some View {
        let expanded = open.contains(title)
        return VStack(spacing: 0) {
            Button {
                withAnimation(reduceMotion ? nil : .snappy) {
                    if expanded { open.remove(title) } else { open.insert(title) }
                }
            } label: {
                HStack(spacing: R.spacingSpace16) {
                    Text(title)
                        .backstageText(.title4)
                        .foregroundStyle(M.textPrimary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Image("spdp_ic_chevron")
                        .resizable()
                        .frame(width: 24, height: 24)
                        .rotationEffect(.degrees(expanded ? -90 : 90))
                }
                .padding(10)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityAddTraits(expanded ? .isSelected : [])
            if expanded {
                VStack(spacing: 0) {
                    ForEach(rows, id: \.0) { r in
                        HStack(alignment: .firstTextBaseline) {
                            Text(r.0).backstageText(.label2).foregroundStyle(M.textTertiary)
                            Spacer(minLength: R.spacingSpace16)
                            Text(r.1).backstageText(.label2).foregroundStyle(M.textPrimary).multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, R.spacingSpace8)
                        .overlay(alignment: .top) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, R.spacingSpace4)
                .transition(.opacity)
            }
        }
        .background(P.rowFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(M.borderModerate, lineWidth: R.stroke1Px))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    // MARK: Action bar

    /// Figma "Action Card Glass": one CTA in a dark glass capsule over a soft blur.
    private func actionBar(_ proxy: ScrollViewProxy) -> some View {
        Button { reserve(proxy) } label: {
            Text("Pay 25% to reserve").frame(maxWidth: .infinity)
        }
        .buttonStyle(BackstagePrimaryButtonStyle())
        .accessibilityHint(size == nil ? "Choose a size first" : (pickupStore == nil ? "Choose a pick-up store next" : "Pay \(rupees(product.reserveNow)) now"))
        .padding(R.spacingSpace16)
        .background(Color.black.opacity(0.56), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: R.stroke1Px))
        .padding(.horizontal, R.spacingSpace12)
        .padding(.bottom, R.spacingSpace8)
        .padding(.top, R.spacingSpace32)
        .background {
            LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                .background(.ultraThinMaterial.opacity(0.6))
                .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    /// Size first (bring the row into view and shake it), then the store, then the reservation.
    private func reserve(_ proxy: ScrollViewProxy) {
        if size == nil {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { proxy.scrollTo("sizes", anchor: .center) }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.45)) { nudge += 1 }
        } else if pickupStore == nil {
            choosingStore = true
        } else {
            reserved = true
        }
    }
}

// MARK: - Hot this week

/// Figma "Genre" pill: the flame and "Hot this week" in a gold-to-white gradient. A status, so no
/// press state.
struct HotThisWeekTag: View {
    var body: some View {
        HStack(spacing: R.spacingSpace4) {
            Image("spdp_ic_hot").resizable().frame(width: 14, height: 14)
            Text("Hot this week")
                .backstageText(.label3)
                .foregroundStyle(LinearGradient(colors: [P.hotGold, M.textPrimary], startPoint: .leading, endPoint: .trailing))
        }
        .padding(.leading, 6)
        .padding(.trailing, R.spacingSpace8)
        .padding(.vertical, R.spacingSpace4)
        .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hot this week")
    }
}

// MARK: - Get it at

/// Figma 8648:10807: the best price after offers on a deep-blue card with a soft light in the
/// corner, a "Save extra" chip, and the bank offers along a dashed foot.
struct StoreOfferCard: View {
    let product: StoreProduct

    var body: some View {
        // Sized to the Figma card; the glows and contents sit in overlays so their own (larger)
        // frames never size the card.
        LinearGradient(colors: [P.offerLeading, P.offerTrailing], startPoint: .leading, endPoint: .trailing)
            .frame(height: 93)
            .overlay(alignment: .topLeading) {
                Image("spdp_offer_glow")
                    .resizable()
                    .frame(width: 390.302, height: 203.195)
                    .offset(x: -22.31 - 282.302 * 0.1913, y: -23.73 - 95.195 * 0.5673)
            }
            .overlay(alignment: .topLeading) {
                Image("spdp_offer_shine")
                    .resizable()
                    .frame(width: 170.051, height: 168.412)
                    .blendMode(.colorDodge)
                    .offset(x: -4.43 - 64.051 * 0.8275, y: -12.25 - 62.412 * 0.8492)
            }
            .overlay(alignment: .topLeading) { bestPrice.padding(.leading, 8.16).padding(.top, 6.29) }
            .overlay(alignment: .topTrailing) { saveExtra.padding(9.25) }
            .overlay(alignment: .bottom) { bankOffers.padding(.bottom, 9.25) }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.75))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Get it at \(rupees(product.bestPrice)) with exclusive and bank offers. Save extra \(rupees(product.saveExtra)).")
    }

    private var bestPrice: some View {
        HStack(spacing: 2) {
            AnimatedGIF(name: "spdp_discount")
                .frame(width: 39, height: 39)
                .scaleEffect(x: -1, y: 1)
            VStack(alignment: .leading, spacing: -1) {
                Text("Get it at")
                    .backstageText(.label2)
                    .foregroundStyle(M.textTertiary)
                Text(rupees(product.bestPrice))
                    .backstageText(.title3)
                    .foregroundStyle(P.grey50)
            }
        }
    }

    /// The dashed rule, then "With exclusive and [banks] bank offers ›".
    private var bankOffers: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Image("spdp_offer_rule").resizable().frame(width: 319, height: 1)
            HStack(spacing: 6) {
                Text("With exclusive and")
                HStack(spacing: -6.4) {
                    ForEach(["spdp_bank_tide", "spdp_bank_idfc", "spdp_bank_hsbc"], id: \.self) { logo in
                        Image(logo)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 16, height: 16)
                            .clipShape(RoundedRectangle(cornerRadius: 10.776, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: 10.776, style: .continuous).strokeBorder(P.logoRing, lineWidth: 0.8))
                    }
                }
                Text("bank offers")
                Spacer(minLength: 0)
                Image("spdp_ic_chevron_small").resizable().frame(width: 20, height: 20)
            }
            .dropFont("Medium", 12)
            .foregroundStyle(M.textSecondary)
        }
        .frame(width: 319)
    }

    private var saveExtra: some View {
        VStack(spacing: -1) {
            Text("Save extra")
                .backstageText(.label3)
                .foregroundStyle(M.textTertiary)
            Text(rupees(product.saveExtra))
                .dropFont("SemiBold", 11, relativeTo: .caption2)
                .foregroundStyle(M.textPrimary)
        }
        .padding(.horizontal, R.spacingSpace8)
        .padding(.vertical, R.spacingSpace4)
        .background(LinearGradient(colors: [P.chipTop, P.chipFoot], startPoint: .top, endPoint: .bottom),
                    in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(rgba: 0x999999FF), lineWidth: 1))
        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Color(rgba: 0x666666FF).opacity(0.2), lineWidth: 1))
        .shadow(color: .black.opacity(0.1), radius: 1.5, y: 2)
    }
}

/// Plays a bundled animated GIF on loop (a still frame with Reduce Motion).
struct AnimatedGIF: UIViewRepresentable {
    let name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeUIView(context: Context) -> UIImageView {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        view.setContentCompressionResistancePriority(.defaultLow, for: .vertical)
        guard let url = Bundle.main.url(forResource: name, withExtension: "gif"),
              let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return view }
        var frames: [UIImage] = []
        var duration: Double = 0
        for i in 0..<CGImageSourceGetCount(source) {
            guard let cg = CGImageSourceCreateImageAtIndex(source, i, nil) else { continue }
            frames.append(UIImage(cgImage: cg))
            let props = CGImageSourceCopyPropertiesAtIndex(source, i, nil) as? [CFString: Any]
            let gif = props?[kCGImagePropertyGIFDictionary] as? [CFString: Any]
            duration += (gif?[kCGImagePropertyGIFUnclampedDelayTime] as? Double) ?? (gif?[kCGImagePropertyGIFDelayTime] as? Double) ?? 0.04
        }
        view.image = reduceMotion ? frames.first : UIImage.animatedImage(with: frames, duration: duration)
        return view
    }

    func updateUIView(_ view: UIImageView, context: Context) {}
}

/// Horizontal shake to point at a missing choice.
private struct StoreShake: ViewModifier {
    var trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.keyframeAnimator(initialValue: CGFloat(0), trigger: trigger) { view, x in
            view.offset(x: reduceMotion ? 0 : x)
        } keyframes: { _ in
            KeyframeTrack {
                SpringKeyframe(10, duration: 0.08)
                SpringKeyframe(-8, duration: 0.08)
                SpringKeyframe(5, duration: 0.08)
                SpringKeyframe(0, duration: 0.1)
            }
        }
    }
}

// MARK: - Pick-up store

/// A branch of the brand to pick up from.
struct StoreBranch: Identifiable, Hashable {
    var id: String { "\(name) \(area)" }
    let name: String
    let area: String
    let distance: String
    let ready: String
}

/// "Select pick-up store": the branch from the Stores list first, then two more nearby.
private struct StorePickupSheet: View {
    let product: StoreProduct
    @Binding var selected: StoreBranch?
    @Environment(\.dismiss) private var dismiss

    private var branches: [StoreBranch] {
        let listed = StoresData.stores.first { $0.name == product.store }
        let home = StoreBranch(name: product.store, area: listed?.area ?? "Golf Course Extension, Gurgaon",
                               distance: listed.map { String(format: "%.1f km", $0.distance) } ?? "2.0 km", ready: "Ready in 2 hours")
        return [home,
                StoreBranch(name: product.store, area: "Ambience Mall, Gurgaon", distance: "5.4 km", ready: "Ready in 3 hours"),
                StoreBranch(name: product.store, area: "Cyberhub, DLF Phase 2", distance: "7.8 km", ready: "Ready tomorrow")]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            HStack {
                Text("Select pick-up store")
                    .dropFont("SemiBold", 18, relativeTo: .title3)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            }
            ForEach(branches) { b in
                let on = selected == b
                Button {
                    selected = b
                    dismiss()
                } label: {
                    HStack(spacing: R.spacingSpace12) {
                        Image("spdp_ic_store").resizable().frame(width: 16, height: 16)
                            .frame(width: 36, height: 36)
                            .background(M.surfaceTransparent, in: Circle())
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(b.name), \(b.area)").backstageText(.title4).foregroundStyle(M.textPrimary).lineLimit(1)
                            Text("\(b.distance) • \(b.ready)").backstageText(.body3).foregroundStyle(M.textTertiary)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: on ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundStyle(on ? M.textPrimary : M.iconTertiary)
                    }
                    .padding(R.spacingSpace12)
                    .background(P.rowFill, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(on ? M.borderSelection : M.borderModerate, lineWidth: R.stroke1Px))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())
                .accessibilityAddTraits(on ? .isSelected : [])
            }
            Spacer(minLength: 0)
        }
        .padding(R.spacingSpace16)
        .presentationDetents([.height(380)])
        .presentationCornerRadius(16)
        .presentationBackground(M.backgroundPrimary)
    }
}

// MARK: - Reserved

private struct StoreReservedSheet: View {
    let product: StoreProduct
    let size: String
    let store: StoreBranch?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: R.spacingSpace16) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 44))
                .foregroundStyle(P.success)
                .padding(.top, R.spacingSpace24)
                .accessibilityHidden(true)
            Text("Reserved for you")
                .dropFont("SemiBold", 18, relativeTo: .title3)
                .foregroundStyle(M.textPrimary)
                .accessibilityAddTraits(.isHeader)
            Text("\(product.name), size \(size). Pay \(rupees(product.reserveNow)) now and \(rupees(product.price - product.reserveNow)) when you pick it up\(store.map { " at \($0.name), \($0.area)" } ?? "").")
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
                .multilineTextAlignment(.center)
            Button("Done") { dismiss() }
                .buttonStyle(BackstagePrimaryButtonStyle())
                .padding(.top, R.spacingSpace8)
        }
        .padding(.horizontal, R.spacingSpace24)
        .frame(maxHeight: .infinity, alignment: .top)
        .presentationDetents([.height(320)])
        .presentationCornerRadius(16)
        .presentationBackground(M.backgroundPrimary)
    }
}

// MARK: - Gallery

/// Every shot full screen, swiped through.
private struct StoreGalleryView: View {
    let shots: [StoreShot]
    @State private var page: Int
    @Environment(\.dismiss) private var dismiss

    init(shots: [StoreShot], start: Int) {
        self.shots = shots
        _page = State(initialValue: start)
    }

    var body: some View {
        TabView(selection: $page) {
            ForEach(Array(shots.enumerated()), id: \.offset) { i, shot in
                StoreShotImage(shot: StoreShot(image: shot.image, zoom: shot.zoom, anchor: shot.anchor))
                    .aspectRatio(3 / 4, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .padding(R.spacingSpace16)
                    .tag(i)
            }
        }
        .tabViewStyle(.page)
        .background(Color.black.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
                .padding(R.spacingSpace16)
        }
        .preferredColorScheme(.dark)
    }
}

/// Which photo the full-screen gallery opens on.
private struct GalleryStart: Identifiable {
    let id: Int
}
