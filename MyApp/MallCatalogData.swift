import SwiftUI
import UIKit

// Shop a mall: every brand's catalogue inside one mall. Stores home shows a moving wall of the mall's brands; it
// opens on a pannable canvas of edits, with the mall switcher in the header. Brands, pieces and prices are sample
// data until live store inventory is wired in.

// MARK: - Pieces

struct MallPiece: Identifiable, Hashable {
    enum Audience: Hashable { case women, men, unisex }

    var id: String { image }
    let image: String
    let name: String
    let brand: String
    let price: Int
    let audience: Audience
    var footwear = false
    /// A packshot on white, shown whole on a white tile instead of filling it.
    var packshot = false

    var priceText: String { MallFormat.rupees(price) }

    /// The canvas's category filter.
    var category: MallFilter.Category {
        if footwear { return .footwear }
        if brand == "Nappa Dori" { return .bags }
        if brand == "Nicobar" || MallCatalog.ethnic.contains(image) { return .ethnic }
        return .clothing
    }

    func fits(_ filter: MallFilter) -> Bool {
        if let c = filter.category, category != c { return false }
        switch filter.gender {
        case .women: if audience == .men { return false }
        case .men: if audience == .women { return false }
        case nil: break
        }
        if filter.payOnDistrict, !(MallCatalog.brands[brand]?.payBill ?? false) { return false }
        return true
    }

    /// The product page model, sold by the brand's store in the mall.
    var product: StoreProduct {
        StoreProduct(image: image, name: name, brand: brand, store: brand, kind: footwear ? .footwear : .apparel,
                     price: price, colour: "As shown")
    }
}

enum MallFormat {
    static func rupees(_ value: Int) -> String {
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.locale = Locale(identifier: "en_IN")
        return "₹" + (f.string(from: NSNumber(value: value)) ?? "\(value)")
    }
}

// MARK: - Brands

struct MallBrand: Hashable {
    let name: String
    /// Logo artwork, if bundled. Brands without one show their name as a word mark.
    let logo: String?
    /// The logo is square artwork that fills its tile.
    var fullBleed = false
    /// The logo is light and needs a black tile.
    var onDark = false
    /// Set under an emblem-only logo, in `captionColor`, when the brand's full lockup is too fine to read small.
    var caption: String? = nil
    var captionColor: UInt32 = 0x000000
    let category: String
    let offer: String
    /// The store takes bill payments on District (not every store on the app does).
    var payBill = true
}

// MARK: - Edits (the canvas cards)

struct MallEdit: Identifiable, Hashable {
    enum Style: Hashable { case billboard, spotlight }

    let id: String
    let kicker: String
    let title: String
    let style: Style
    /// Spotlights fan the first two behind the logo; billboards keep their source photo here.
    let covers: [String]
    var brand: MallBrand? = nil
    let pieces: [MallPiece]
    /// Billboards: the serif title's roman lead and italic line, the solid ground, and the cut-out piece.
    var lead = ""
    var italic = ""
    var ground: Color = .black
    var art: String? = nil

    static func == (a: MallEdit, b: MallEdit) -> Bool { a.id == b.id }
    func hash(into h: inout Hasher) { h.combine(id) }

    /// The collection's header line: who sells these pieces in the mall.
    var sellers: String {
        var seen: [String] = []
        for p in pieces where !seen.contains(p.brand) { seen.append(p.brand) }
        if seen.count <= 3 { return seen.joined(separator: ", ") }
        return seen.prefix(3).joined(separator: ", ") + " +\(seen.count - 3)"
    }

    /// A brand stays while it has a matching piece; a billboard needs three.
    func fits(_ filter: MallFilter) -> Bool {
        guard !filter.isEmpty else { return true }
        return pieces.filter { $0.fits(filter) }.count >= (style == .spotlight ? 1 : 3)
    }

    /// The edit as seen under the filters: only the pieces that match them.
    func narrowed(to filter: MallFilter) -> MallEdit {
        guard !filter.isEmpty else { return self }
        let kept = pieces.filter { $0.fits(filter) }
        return MallEdit(id: id, kicker: kicker, title: title, style: style, covers: covers, brand: brand,
                        pieces: kept.isEmpty ? pieces : kept, lead: lead, italic: italic, ground: ground, art: art)
    }
}

/// The canvas's filters: a category, a gender, and stores you can pay your bill at on District. Any mix.
struct MallFilter: Hashable {
    enum Category: String, CaseIterable, Identifiable {
        case clothing, footwear, ethnic, bags
        var id: String { rawValue }
        var title: String {
            switch self {
            case .clothing: "Clothing"
            case .footwear: "Footwear"
            case .ethnic: "Ethnic & festive"
            case .bags: "Bags & leather"
            }
        }
    }

    enum Gender: String { case women, men }

    var category: Category?
    var gender: Gender?
    var payOnDistrict = false

    var isEmpty: Bool { category == nil && gender == nil && !payOnDistrict }

    /// "Footwear · Women · Pay via District", for the header.
    var title: String {
        [category?.title, gender.map { $0 == .women ? "Women" : "Men" }, payOnDistrict ? "Pay via District" : nil]
            .compactMap { $0 }.joined(separator: " · ")
    }

    /// Distinguishes card ids between filter states.
    var key: String { "\(category?.rawValue ?? "-")-\(gender?.rawValue ?? "-")-\(payOnDistrict)" }
}

// MARK: - Malls

struct MallShop: Identifiable, Hashable {
    var id: String { name }
    let name: String
    /// A short name, for tight spots.
    let short: String
    let brands: [String]

    static func == (a: MallShop, b: MallShop) -> Bool { a.name == b.name }
    func hash(into h: inout Hasher) { h.combine(name) }

    var hub: Hub? { HubsData.hub(named: name) }
    var area: String { hub?.locality ?? "" }
    var distance: String { hub?.distance ?? "" }
    var glow: Color { hub?.glow ?? Color(hex: 0x748599) }

    var pieces: [MallPiece] { MallCatalog.pieces.filter { brands.contains($0.brand) } }
    var edits: [MallEdit] { MallCatalog.edits(for: self) }

    /// "10 brands · 86 pieces".
    var summary: String { "\(brands.count) brands · \(pieces.count) pieces" }

    /// Brands with a store page in this mall (a spotlight edit): the tiles on the brand wall.
    var wallBrands: [MallBrand] {
        let spotlit = Set(edits.compactMap { $0.brand?.name })
        return brands.compactMap { MallCatalog.brands[$0] }.filter { spotlit.contains($0.name) }
    }

    /// Which floor a brand's store is on, fixed per mall.
    func floor(of brand: String) -> Int {
        (name + brand).unicodeScalars.reduce(0) { $0 + Int($1.value) } % 3 + 1
    }
}

// MARK: - Catalogue

enum MallCatalog {
    static let malls: [MallShop] = [
        MallShop(name: "Ambience Mall", short: "Ambience",
                 brands: ["Zara", "H&M", "adidas", "Uniqlo", "Nicobar", "Puma", "Nappa Dori", "Superdry", "ASICS", "Snitch"]),
        MallShop(name: "DLF Promenade", short: "Promenade",
                 brands: ["Zara", "H&M", "adidas", "Puma", "Bonkers Corner", "The Souled Store", "New Balance", "Doodlage", "Nappa Dori"]),
        MallShop(name: "Select Citywalk", short: "Select Citywalk",
                 brands: ["Zara", "H&M", "Uniqlo", "Nicobar", "Gully Labs", "adidas", "Superdry", "The Souled Store", "New Balance"]),
        MallShop(name: "MGF Metropolitan Mall", short: "MGF Metropolitan",
                 brands: ["H&M", "Snitch", "Bonkers Corner", "Puma", "ASICS", "Peter England", "The Souled Store", "Doodlage"]),
        MallShop(name: "Good Earth City Center", short: "City Center",
                 brands: ["Snitch", "Bonkers Corner", "Puma", "Peter England", "Uniqlo", "Gully Labs"]),
    ]

    static func mall(named name: String) -> MallShop? {
        malls.first { $0.name == name || $0.short == name || $0.name.lowercased().hasPrefix(name.lowercased()) }
    }

    static let brands: [String: MallBrand] = Dictionary(uniqueKeysWithValues: [
        MallBrand(name: "adidas", logo: "logo_adidas", category: "Sports & footwear", offer: "Flat ₹1,000 off"),
        MallBrand(name: "Puma", logo: "mall_logo_puma", fullBleed: true, category: "Sneakers & sportswear", offer: "Extra 10% on District"),
        MallBrand(name: "ASICS", logo: "mall_logo_asics", category: "Running", offer: "Flat ₹800 off"),
        MallBrand(name: "New Balance", logo: "pd_logo_nb", category: "Sneakers", offer: "No cost EMI"),
        MallBrand(name: "Zara", logo: "logo_zara", category: "Fashion & accessories", offer: "Bank offers", payBill: false),
        MallBrand(name: "H&M", logo: "logo_hm", category: "Fashion", offer: "Flat ₹500 off"),
        MallBrand(name: "Uniqlo", logo: "hub_logo_uniqlo", fullBleed: true, category: "Everyday essentials", offer: "Flat ₹300 off", payBill: false),
        MallBrand(name: "Nicobar", logo: "logo_nicobar", onDark: true, category: "Ethnic & home", offer: "15% off on ₹5,000+"),
        MallBrand(name: "Snitch", logo: "logo_snitch", fullBleed: true, category: "Menswear", offer: "Flat ₹300 off"),
        MallBrand(name: "Bonkers Corner", logo: "logo_bonkers_corner", fullBleed: true, category: "Streetwear", offer: "Flat ₹700 off"),
        MallBrand(name: "The Souled Store", logo: "logo_the_souled_store", fullBleed: true, category: "Pop culture & tees", offer: "Flat ₹500 off"),
        MallBrand(name: "Nappa Dori", logo: "mall_logo_nappa", onDark: true, caption: "NAPPA DORI", captionColor: 0xA87E55, category: "Leather & travel", offer: "Free monogramming"),
        MallBrand(name: "Superdry", logo: "mall_logo_superdry", fullBleed: true, category: "Denim & outerwear", offer: "Flat ₹1,000 off", payBill: false),
        MallBrand(name: "Gully Labs", logo: "logo_gully_labs", category: "Homegrown sneakers", offer: "Flat ₹400 off"),
        MallBrand(name: "Doodlage", logo: "logo_doodlage", category: "Upcycled fashion", offer: "Flat ₹300 off", payBill: false),
        MallBrand(name: "Peter England", logo: "logo_peter_england", category: "Formalwear", offer: "Flat ₹600 off", payBill: false),
    ].map { ($0.name, $0) })

    // swiftlint:disable line_length
    static let pieces: [MallPiece] = [
        // adidas
        MallPiece(image: "rack_adidas_popper", name: "Adibreak popper track pants", brand: "adidas", price: 5999, audience: .women),
        MallPiece(image: "rack_adidas_track", name: "Fleece jogger set", brand: "adidas", price: 6999, audience: .women),
        MallPiece(image: "plan_active_1", name: "Retro high-top sneakers", brand: "adidas", price: 9999, audience: .unisex, footwear: true),
        MallPiece(image: "plan_active_2", name: "Essentials fleece hoodie", brand: "adidas", price: 4599, audience: .women),
        MallPiece(image: "pd_adizero", name: "Adizero Boston 12", brand: "adidas", price: 13999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_supernova", name: "Supernova Rise", brand: "adidas", price: 11999, audience: .men, footwear: true, packshot: true),
        MallPiece(image: "sdp_cat_c1_big", name: "Hooded parka with faux-fur trim", brand: "adidas", price: 6999, audience: .women),
        MallPiece(image: "sdp_cat_c1_tr", name: "Belted longline puffer", brand: "adidas", price: 8999, audience: .women),
        MallPiece(image: "sdp_cat_c1_mr", name: "Cropped puffer jacket", brand: "adidas", price: 4999, audience: .women),
        MallPiece(image: "sdp_cat_c1_b1", name: "Hooded puffer jacket", brand: "adidas", price: 5499, audience: .women),
        MallPiece(image: "vogue_fit_active", name: "Wide-leg track pants", brand: "adidas", price: 4299, audience: .women),
        MallPiece(image: "plan_active_hero", name: "Training tank & tights", brand: "adidas", price: 3999, audience: .women),
        // Puma
        MallPiece(image: "pd_speedcat", name: "Speedcat OG", brand: "Puma", price: 9999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_speedguard_red", name: "Speedcat suede, red", brand: "Puma", price: 8999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_speedguard_yellow", name: "Speedcat suede, yellow", brand: "Puma", price: 8999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_speedguard_blue", name: "Speedcat suede, blue", brand: "Puma", price: 8999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_speedguard_black", name: "Speedcat suede, black", brand: "Puma", price: 8999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_runnitro", name: "Deviate Nitro 3", brand: "Puma", price: 12999, audience: .men, footwear: true, packshot: true),
        MallPiece(image: "pd_hot_hoodie", name: "Graphic logo tee", brand: "Puma", price: 2299, audience: .unisex),
        MallPiece(image: "pd_hot_back", name: "Oversized fleece hoodie", brand: "Puma", price: 4999, audience: .women),
        MallPiece(image: "pd_speedguard_model", name: "Track co-ord set", brand: "Puma", price: 5999, audience: .women),
        // ASICS
        MallPiece(image: "pd_gel1130", name: "GEL-1130", brand: "ASICS", price: 10999, audience: .unisex, footwear: true, packshot: true),
        MallPiece(image: "pd_gel_quantum", name: "GEL-Quantum 360", brand: "ASICS", price: 13999, audience: .men, footwear: true, packshot: true),
        // New Balance
        MallPiece(image: "pd_nb9060", name: "9060", brand: "New Balance", price: 16999, audience: .unisex, footwear: true, packshot: true),
        // Zara
        MallPiece(image: "rack_zara_dress", name: "Fit-and-flare mini dress", brand: "Zara", price: 3990, audience: .women),
        MallPiece(image: "rack_zara_blazer", name: "Oversized blazer suit", brand: "Zara", price: 7990, audience: .women),
        MallPiece(image: "plan_office_1", name: "Turtleneck & plaid skirt set", brand: "Zara", price: 4590, audience: .women),
        MallPiece(image: "plan_office_3", name: "Sheer embroidered blouse", brand: "Zara", price: 2990, audience: .women),
        MallPiece(image: "sdp_cat_c2_big", name: "Button-front denim dress", brand: "Zara", price: 2490, audience: .women),
        MallPiece(image: "sdp_cat_c2_tr", name: "Floral wrap mini dress", brand: "Zara", price: 2290, audience: .women),
        MallPiece(image: "sdp_cat_c2_b1", name: "Twist-front midi dress", brand: "Zara", price: 2790, audience: .women),
        MallPiece(image: "look_parisian_edge", name: "Houndstooth wool coat", brand: "Zara", price: 8990, audience: .women),
        MallPiece(image: "vogue_look_ivory", name: "Ivory wide-leg suit", brand: "Zara", price: 7590, audience: .women),
        MallPiece(image: "plan_first_date_3", name: "Lace cut-out dress", brand: "Zara", price: 4990, audience: .women),
        MallPiece(image: "vogue_pair_shorts", name: "Belted tailored shorts", brand: "Zara", price: 2590, audience: .women),
        MallPiece(image: "vogue_pair_skort", name: "Pinstripe skort", brand: "Zara", price: 2290, audience: .women),
        // H&M
        MallPiece(image: "rack_hm_overcoat", name: "Wool-blend overcoat", brand: "H&M", price: 7999, audience: .women),
        MallPiece(image: "look_camel_coat", name: "Belted camel coat", brand: "H&M", price: 6999, audience: .women),
        MallPiece(image: "photo_rose_1", name: "Chunky knit jumper", brand: "H&M", price: 2299, audience: .women),
        MallPiece(image: "photo_rose_3", name: "Pleated jogger trousers", brand: "H&M", price: 1999, audience: .women),
        MallPiece(image: "staple_white_tee_1", name: "Printed graphic tee", brand: "H&M", price: 799, audience: .women),
        MallPiece(image: "palette_slate-noir_2", name: "Relaxed sweatshirt", brand: "H&M", price: 1999, audience: .men),
        MallPiece(image: "vto_outfit", name: "Oversized sweatshirt", brand: "H&M", price: 1799, audience: .women),
        MallPiece(image: "plan_first_date_2", name: "Sailor-button trousers", brand: "H&M", price: 2299, audience: .women),
        MallPiece(image: "sdp_cat_c2_b2", name: "Puff-sleeve floral dress", brand: "H&M", price: 1999, audience: .women),
        MallPiece(image: "photo_rose_2", name: "Satin bomber jacket", brand: "H&M", price: 3499, audience: .women),
        // Uniqlo
        MallPiece(image: "staple_white_tee", name: "Supima cotton crew tee", brand: "Uniqlo", price: 990, audience: .men),
        MallPiece(image: "staple_white_tee_2", name: "AIRism oversized tee", brand: "Uniqlo", price: 1290, audience: .men),
        MallPiece(image: "palette_sage-linen_2", name: "Souffle yarn jumper", brand: "Uniqlo", price: 2990, audience: .women),
        MallPiece(image: "palette_sage-linen_3", name: "Crochet poncho", brand: "Uniqlo", price: 2490, audience: .women),
        MallPiece(image: "palette_butter-denim_4", name: "Chambray shirt", brand: "Uniqlo", price: 2490, audience: .men),
        MallPiece(image: "vogue_pair_jeans", name: "Straight-leg jeans", brand: "Uniqlo", price: 2990, audience: .women, packshot: true),
        MallPiece(image: "palette_sage-linen_1", name: "Linen-blend shirts", brand: "Uniqlo", price: 2490, audience: .men),
        // Nicobar
        MallPiece(image: "rack_nicobar_kaftan", name: "Embroidered cotton kaftan", brand: "Nicobar", price: 6450, audience: .women),
        MallPiece(image: "plan_diwali_1", name: "Silk saree with zari border", brand: "Nicobar", price: 14500, audience: .women),
        MallPiece(image: "plan_diwali_2", name: "Banarasi silk saree", brand: "Nicobar", price: 16900, audience: .women),
        MallPiece(image: "plan_wedding_3", name: "Tiered maxi dress", brand: "Nicobar", price: 7450, audience: .women),
        MallPiece(image: "plan_diwali_hero", name: "Embroidered kurta set", brand: "Nicobar", price: 9850, audience: .women),
        MallPiece(image: "vogue_pair_kurti", name: "Chikankari short kurta", brand: "Nicobar", price: 3450, audience: .women, packshot: true),
        // Snitch
        MallPiece(image: "rack_snitch_biker", name: "Leather biker jacket", brand: "Snitch", price: 3999, audience: .men),
        MallPiece(image: "staple_denim_1", name: "Classic denim jacket", brand: "Snitch", price: 2299, audience: .men),
        MallPiece(image: "palette_midnight-olive_3", name: "Suede jacket over oxford", brand: "Snitch", price: 4499, audience: .men),
        MallPiece(image: "staple_blazer_3", name: "Unstructured blazer", brand: "Snitch", price: 3499, audience: .men),
        MallPiece(image: "palette_midnight-olive_5", name: "Printed resort shirt", brand: "Snitch", price: 1499, audience: .men),
        MallPiece(image: "sdp_store_snitch", name: "Textured black shirt", brand: "Snitch", price: 1799, audience: .men),
        MallPiece(image: "palette_slate-noir_5", name: "Faux-leather jacket", brand: "Snitch", price: 3299, audience: .men),
        // Bonkers Corner
        MallPiece(image: "rack_bonkers_patchwork", name: "Patchwork denim co-ord", brand: "Bonkers Corner", price: 4999, audience: .unisex),
        MallPiece(image: "rack_bonkers_jeans", name: "Distressed patch jeans", brand: "Bonkers Corner", price: 2799, audience: .men),
        MallPiece(image: "staple_white_tee_3", name: "Boxy logo tee", brand: "Bonkers Corner", price: 1299, audience: .men),
        MallPiece(image: "vogue_pair_graphic_tee", name: "Varsity graphic tee", brand: "Bonkers Corner", price: 1199, audience: .unisex),
        MallPiece(image: "vogue_pair_black_tee", name: "Tiger graphic tee", brand: "Bonkers Corner", price: 1199, audience: .unisex),
        // The Souled Store
        MallPiece(image: "rack_tss_tee", name: "Originals oversized tee", brand: "The Souled Store", price: 1199, audience: .unisex),
        MallPiece(image: "vogue_pair_tee", name: "Vintage wash tee", brand: "The Souled Store", price: 999, audience: .unisex, packshot: true),
        MallPiece(image: "vogue_look_oranges", name: "Football jersey", brand: "The Souled Store", price: 1499, audience: .women),
        MallPiece(image: "palette_butter-denim_3", name: "Graphic tee & joggers", brand: "The Souled Store", price: 2499, audience: .unisex),
        // Nappa Dori
        MallPiece(image: "article_nappa_1", name: "Leather daypack", brand: "Nappa Dori", price: 8950, audience: .unisex),
        MallPiece(image: "article_nappa_2", name: "Leather oxford shoes", brand: "Nappa Dori", price: 9450, audience: .men, footwear: true),
        MallPiece(image: "palette_midnight-olive_2", name: "Nylon city backpack", brand: "Nappa Dori", price: 5950, audience: .unisex),
        MallPiece(image: "vogue_pair_leathers", name: "Leather tote", brand: "Nappa Dori", price: 7450, audience: .women),
        // Superdry
        MallPiece(image: "palette_slate-noir_4", name: "Vintage denim jacket", brand: "Superdry", price: 6999, audience: .men),
        MallPiece(image: "staple_denim_3", name: "Hooded denim jacket", brand: "Superdry", price: 5999, audience: .women),
        MallPiece(image: "palette_midnight-olive_4", name: "Sport stripe tee", brand: "Superdry", price: 2999, audience: .men),
        MallPiece(image: "staple_denim", name: "Selvedge jeans", brand: "Superdry", price: 5499, audience: .men),
        // Gully Labs
        MallPiece(image: "article_gully_1", name: "Tan leather low-tops", brand: "Gully Labs", price: 7999, audience: .unisex, footwear: true),
        MallPiece(image: "article_gully_2", name: "Burgundy suede kicks", brand: "Gully Labs", price: 7499, audience: .unisex, footwear: true),
        MallPiece(image: "palette_butter-denim_6", name: "Mustard court sneakers", brand: "Gully Labs", price: 6999, audience: .unisex, footwear: true),
        MallPiece(image: "vogue_brand_gully", name: "Hand-painted high-tops", brand: "Gully Labs", price: 8499, audience: .unisex, footwear: true),
        // Doodlage
        MallPiece(image: "article_doodlage_2", name: "Upcycled denim shirt", brand: "Doodlage", price: 3800, audience: .unisex),
        MallPiece(image: "article_doodlage_3", name: "Patchwork crop shirt", brand: "Doodlage", price: 3200, audience: .women),
        MallPiece(image: "palette_sage-linen_4", name: "Upcycled knit cardigan", brand: "Doodlage", price: 4200, audience: .women),
        MallPiece(image: "palette_sage-linen_5", name: "Oversized shirt dress", brand: "Doodlage", price: 4600, audience: .women),
        // Peter England
        MallPiece(image: "staple_blazer", name: "Navy two-button suit", brand: "Peter England", price: 11999, audience: .men),
        MallPiece(image: "staple_blazer_1", name: "Slim-fit blazer", brand: "Peter England", price: 6999, audience: .men),
        MallPiece(image: "staple_blazer_2", name: "Checked two-piece suit", brand: "Peter England", price: 12999, audience: .men),
    ]
    // swiftlint:enable line_length

    private static let byImage: [String: MallPiece] = Dictionary(uniqueKeysWithValues: pieces.map { ($0.image, $0) })

    static func piece(_ image: String) -> MallPiece? { byImage[image] }

    /// Ethnic and festive pieces outside Nicobar, for the category filter.
    static let ethnic: Set<String> = ["plan_diwali_1", "plan_diwali_2", "plan_diwali_hero", "vogue_pair_kurti"]

    /// Whose picks the saves go to (the profile avatar's "N").
    static let shopperName = "Nidhi"

    // MARK: Themes

    /// A cross-brand edit, shown on the canvas as a billboard: a solid ground, a small-caps line, a serif title
    /// (a roman lead, then an italic line) and a cut-out piece. Its pieces are whatever the mall's brands carry
    /// from `images`; the cut-out is the first of `art` the mall stocks.
    private struct Theme {
        let id: String
        let kicker: String
        let lead: String
        let italic: String
        let ground: UInt32
        let art: [String]
        let images: [String]
    }

    /// Pieces with a lifted-out cut-out bundled (Assets › MallArt › mall_cut_<image>).
    static let cutouts: Set<String> = [
        "article_doodlage_2", "article_gully_2", "article_nappa_1", "look_camel_coat", "palette_butter-denim_4",
        "palette_midnight-olive_2", "palette_midnight-olive_5", "palette_sage-linen_2", "palette_sage-linen_3", "palette_slate-noir_4",
        "pd_adizero", "pd_gel1130", "pd_nb9060", "pd_speedcat", "pd_speedguard_model", "pd_speedguard_red", "photo_rose_1",
        "plan_active_2", "plan_diwali_1", "plan_diwali_2", "plan_wedding_3", "rack_adidas_popper", "rack_adidas_track",
        "rack_bonkers_jeans", "rack_bonkers_patchwork", "rack_hm_overcoat", "rack_nicobar_kaftan", "rack_snitch_biker", "rack_tss_tee",
        "rack_zara_blazer", "rack_zara_dress", "sdp_cat_c1_big", "sdp_cat_c2_b2", "sdp_cat_c2_tr", "sdp_store_snitch", "staple_blazer_1",
        "staple_blazer_3", "staple_denim_1", "staple_denim_3", "staple_white_tee_1", "staple_white_tee_2", "vogue_look_oranges",
        "vogue_pair_jeans", "vogue_pair_kurti", "vogue_pair_leathers", "vogue_pair_tee",
    ]

    private static let themes: [Theme] = [
        Theme(id: "sneakers", kicker: "Trending now", lead: "Sneakers", italic: "worth the queue", ground: 0xB8322E,
              art: ["pd_speedguard_red", "pd_nb9060", "pd_gel1130", "pd_adizero", "pd_speedcat", "article_gully_2"],
              images: ["pd_speedcat", "pd_nb9060", "pd_gel1130", "pd_adizero", "plan_active_1", "pd_speedguard_red", "article_gully_1",
                       "article_gully_2", "pd_supernova", "pd_gel_quantum", "pd_runnitro", "pd_speedguard_yellow", "vogue_brand_gully",
                       "palette_butter-denim_6", "pd_speedguard_blue", "pd_speedguard_black"]),
        Theme(id: "winter", kicker: "Layer up", lead: "Delhi winter", italic: "layers", ground: 0x14213F,
              art: ["look_camel_coat", "rack_hm_overcoat", "rack_snitch_biker", "palette_slate-noir_4", "sdp_cat_c1_big"],
              images: ["rack_hm_overcoat", "look_camel_coat", "look_parisian_edge", "sdp_cat_c1_big", "sdp_cat_c1_tr", "sdp_cat_c1_mr",
                       "sdp_cat_c1_b1", "palette_sage-linen_2", "photo_rose_1", "rack_snitch_biker", "palette_slate-noir_4", "pd_hot_back",
                       "palette_midnight-olive_3", "staple_denim_3"]),
        Theme(id: "festive", kicker: "Festive season", lead: "The festive", italic: "edit", ground: 0x5A1A2E,
              art: ["plan_diwali_2", "plan_diwali_1", "rack_nicobar_kaftan", "vogue_pair_kurti"],
              images: ["plan_diwali_1", "plan_diwali_2", "plan_diwali_hero", "rack_nicobar_kaftan", "vogue_pair_kurti", "plan_wedding_3"]),
        Theme(id: "office", kicker: "Monday ready", lead: "Office,", italic: "but sharper", ground: 0x2B3440,
              art: ["rack_zara_blazer", "staple_blazer_1", "staple_blazer_3", "sdp_store_snitch", "palette_butter-denim_4"],
              images: ["rack_zara_blazer", "plan_office_1", "plan_office_3", "vogue_look_ivory", "staple_blazer_3", "staple_blazer_1",
                       "staple_blazer", "staple_blazer_2", "palette_midnight-olive_3", "palette_butter-denim_4", "sdp_store_snitch",
                       "plan_first_date_2"]),
        Theme(id: "denim", kicker: "Every wash", lead: "Denim", italic: "days", ground: 0x1E3A6B,
              art: ["vogue_pair_jeans", "staple_denim_3", "rack_bonkers_jeans", "staple_denim_1", "palette_slate-noir_4"],
              images: ["staple_denim_1", "rack_bonkers_jeans", "vogue_pair_jeans", "palette_slate-noir_4", "staple_denim_3", "sdp_cat_c2_big",
                       "article_doodlage_2", "staple_denim", "rack_bonkers_patchwork", "palette_butter-denim_4"]),
        Theme(id: "dates", kicker: "Date night", lead: "Dinner-plan", italic: "dresses", ground: 0x4A1530,
              art: ["rack_zara_dress", "sdp_cat_c2_tr", "sdp_cat_c2_b2", "plan_wedding_3"],
              images: ["rack_zara_dress", "sdp_cat_c2_tr", "sdp_cat_c2_b1", "sdp_cat_c2_b2", "plan_first_date_3", "plan_wedding_3",
                       "palette_sage-linen_5", "sdp_cat_c2_big", "photo_rose_2"]),
        Theme(id: "tees", kicker: "Basics", lead: "The perfect", italic: "tee hunt", ground: 0x1F4031,
              art: ["rack_tss_tee", "vogue_pair_tee", "staple_white_tee_2", "staple_white_tee_1"],
              images: ["staple_white_tee", "staple_white_tee_2", "staple_white_tee_1", "staple_white_tee_3", "rack_tss_tee", "vogue_pair_tee",
                       "vogue_pair_graphic_tee", "vogue_pair_black_tee", "pd_hot_hoodie", "palette_midnight-olive_4"]),
        Theme(id: "street", kicker: "Homegrown labels", lead: "Loud fits,", italic: "made local", ground: 0xB5541C,
              art: ["rack_bonkers_patchwork", "vogue_look_oranges", "rack_tss_tee", "rack_bonkers_jeans"],
              images: ["rack_bonkers_patchwork", "rack_tss_tee", "vogue_pair_graphic_tee", "vogue_pair_black_tee", "vogue_look_oranges",
                       "rack_bonkers_jeans", "staple_white_tee_3", "palette_butter-denim_3", "article_doodlage_3", "palette_midnight-olive_5"]),
        Theme(id: "leather", kicker: "Ages well", lead: "Leather", italic: "goods", ground: 0x5B3A22,
              art: ["article_nappa_1", "palette_midnight-olive_2", "vogue_pair_leathers", "rack_snitch_biker"],
              images: ["article_nappa_1", "article_nappa_2", "palette_midnight-olive_2", "vogue_pair_leathers", "rack_snitch_biker",
                       "palette_slate-noir_5", "article_gully_1", "palette_midnight-olive_3"]),
        Theme(id: "active", kicker: "Gym to brunch", lead: "Move", italic: "in style", ground: 0x0F4C4A,
              art: ["rack_adidas_track", "rack_adidas_popper", "pd_speedguard_model", "plan_active_2"],
              images: ["rack_adidas_popper", "rack_adidas_track", "plan_active_2", "vogue_fit_active", "plan_active_hero", "pd_speedguard_model",
                       "pd_hot_back", "pd_runnitro", "pd_adizero", "pd_supernova", "pd_gel_quantum"]),
        Theme(id: "knits", kicker: "Soft layers", lead: "Knits to", italic: "live in", ground: 0x5E4A62,
              art: ["palette_sage-linen_3", "palette_sage-linen_2", "photo_rose_1", "plan_active_2"],
              images: ["palette_sage-linen_2", "palette_sage-linen_3", "photo_rose_1", "palette_sage-linen_4", "plan_active_2",
                       "palette_slate-noir_2", "vto_outfit", "pd_hot_back"]),
        Theme(id: "shirts", kicker: "Point of view", lead: "Shirts with", italic: "an opinion", ground: 0x7A5A17,
              art: ["palette_butter-denim_4", "article_doodlage_2", "palette_midnight-olive_5", "sdp_store_snitch"],
              images: ["palette_midnight-olive_5", "sdp_store_snitch", "palette_butter-denim_4", "article_doodlage_2", "article_doodlage_3",
                       "palette_sage-linen_1", "plan_office_3", "vogue_pair_kurti"]),
    ]

    private static var editCache: [String: [MallEdit]] = [:]

    /// The mall's edits, brands first: a store spotlight per brand, then the cross-brand billboards it stocks at
    /// least four pieces of, and a "steals" billboard.
    static func edits(for mall: MallShop) -> [MallEdit] {
        if let cached = editCache[mall.name] { return cached }
        let stocked = Set(mall.pieces.map(\.image))

        let spotlights: [MallEdit] = mall.brands.compactMap { name in
            guard let brand = brands[name] else { return nil }
            let pieces = mall.pieces.filter { $0.brand == name }
            guard pieces.count >= 2 else { return nil }
            let photos = pieces.filter { !$0.packshot }.map(\.image) + pieces.filter(\.packshot).map(\.image)
            return MallEdit(id: "brand-\(name)", kicker: "Floor \(mall.floor(of: name)) · \(brand.category)",
                            title: "Spotlight: \(name)", style: .spotlight, covers: Array(photos.prefix(3)), brand: brand, pieces: pieces)
        }

        func billboard(id: String, kicker: String, lead: String, italic: String, ground: UInt32, art: [String], pieces: [MallPiece]) -> MallEdit {
            let names = Set(pieces.map(\.image))
            let cut = art.first { names.contains($0) && cutouts.contains($0) } ?? pieces.first { cutouts.contains($0.image) }?.image
            return MallEdit(id: id, kicker: kicker, title: "\(lead) \(italic)", style: .billboard,
                            covers: [cut ?? pieces[0].image], pieces: pieces,
                            lead: lead, italic: italic, ground: Color(hex: ground), art: cut.map { "mall_cut_\($0)" })
        }

        var billboards: [MallEdit] = themes.compactMap { theme in
            let pieces = theme.images.filter(stocked.contains).compactMap { byImage[$0] }
            guard pieces.count >= 4 else { return nil }
            return billboard(id: theme.id, kicker: theme.kicker, lead: theme.lead, italic: theme.italic, ground: theme.ground,
                             art: theme.art, pieces: pieces)
        }
        let steals = mall.pieces.filter { $0.price < 2500 }.sorted { $0.price < $1.price }
        if steals.count >= 4 {
            billboards.append(billboard(id: "steals", kicker: "Under ₹2,500", lead: "Great finds,", italic: "small prices", ground: 0x3B2A7A,
                                        art: ["rack_tss_tee", "vogue_pair_tee", "staple_white_tee_1", "staple_white_tee_2", "palette_midnight-olive_5"],
                                        pieces: steals))
        }

        let all = spotlights + billboards
        editCache[mall.name] = all
        return all
    }

    // MARK: Helpers

    /// A repeatable shuffle, so a mall's brand wall reads the same each time.
    static func shuffled<T>(_ items: [T], seed: String) -> [T] {
        var state = UInt64(seed.unicodeScalars.reduce(1469598103934665603) { ($0 ^ UInt64($1.value)) &* 1099511628211 })
        var out = items
        guard out.count > 1 else { return out }
        for i in stride(from: out.count - 1, to: 0, by: -1) {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            let j = Int((state >> 33) % UInt64(i + 1))
            out.swapAt(i, j)
        }
        return out
    }
}

// MARK: - Saved pieces

/// Pieces saved while browsing a mall. Shared by the canvas, its collections and the picks screen.
@Observable
final class MallPicks {
    private(set) var saved: [MallPiece] = []
    /// The latest save, for the toast.
    private(set) var lastSaved: MallPiece?
    private(set) var saveCount = 0

    func contains(_ piece: MallPiece) -> Bool { saved.contains(piece) }

    func toggle(_ piece: MallPiece) {
        if let i = saved.firstIndex(of: piece) {
            saved.remove(at: i)
        } else {
            saved.insert(piece, at: 0)
            lastSaved = piece
            saveCount += 1
        }
    }
}

// MARK: - Image cache

/// Downsampled copies of the catalogue photos, made off the main thread, so a canvas of dozens of cards never
/// decodes full-size photos while it pans.
final class MallImages: @unchecked Sendable {
    static let shared = MallImages()

    private let cache = NSCache<NSString, UIImage>()

    func cached(_ name: String) -> UIImage? { cache.object(forKey: name as NSString) }

    func load(_ name: String) async -> UIImage? {
        if let hit = cached(name) { return hit }
        let made = await Task.detached(priority: .userInitiated) { Self.make(name) }.value
        if let made { cache.setObject(made, forKey: name as NSString) }
        return made
    }

    /// Loads every image in parallel.
    func preload(_ names: [String]) async {
        let missing = Set(names).filter { cached($0) == nil }
        guard !missing.isEmpty else { return }
        await withTaskGroup(of: (String, UIImage?).self) { group in
            for n in missing {
                group.addTask(priority: .userInitiated) { (n, Self.make(n)) }
            }
            for await (n, image) in group {
                if let image { cache.setObject(image, forKey: n as NSString) }
            }
        }
    }

    /// Packshots exported with rounded corners on black: cropped in past the corners.
    private static let cornerCropped: Set<String> = ["pd_speedguard_red", "pd_speedguard_yellow", "pd_speedguard_blue", "pd_speedguard_black"]

    private static func make(_ name: String) -> UIImage? {
        guard var source = UIImage(named: name) else { return nil }
        if cornerCropped.contains(name), let cg = source.cgImage {
            let inset = CGFloat(min(cg.width, cg.height)) * 0.06
            let rect = CGRect(x: 0, y: 0, width: cg.width, height: cg.height).insetBy(dx: inset, dy: inset)
            if let cropped = cg.cropping(to: rect) {
                source = UIImage(cgImage: cropped, scale: source.scale, orientation: source.imageOrientation)
            }
        }
        let shortSide: CGFloat = 520
        let s = source.size
        let scale = min(1, shortSide / max(1, min(s.width * source.scale, s.height * source.scale)))
        let target = CGSize(width: (s.width * source.scale * scale).rounded(), height: (s.height * source.scale * scale).rounded())
        return source.preparingThumbnail(of: target) ?? source
    }
}
