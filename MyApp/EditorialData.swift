import SwiftUI

extension Color {
    /// Content colour from 0xRRGGBB (palette swatches and photo placeholders only, never UI chrome).
    init(hex: UInt32) {
        self.init(rgba: hex << 8 | 0xFF)
    }
}

/// A piece of imagery. If an asset named `image` exists in the asset catalog it is
/// shown; otherwise a generative placeholder is drawn from `hexes`, `symbol` and `seed`.
struct Art: Hashable {
    var image: String?
    var hexes: [UInt32]
    var symbol: String
    var seed: Int

    init(_ image: String?, _ hexes: [UInt32], symbol: String = "figure.stand", seed: Int = 0) {
        self.image = image
        self.hexes = hexes
        self.symbol = symbol
        self.seed = seed
    }

    var colors: [Color] { hexes.map { Color(hex: $0) } }

    /// Deterministic value in -0.5...0.5 used to vary placeholder composition.
    var jitter: CGFloat { CGFloat((abs(seed) &* 7919) % 1000) / 1000 - 0.5 }
}

struct Story: Identifiable {
    var id: String { brand }
    let brand: String
    let mark: String
    let title: String
    let art: Art
}

/// Long-form brand story shown in the reader.
struct StoryArticle {
    enum Block {
        case paragraph(String)
        case heading(String)
        case quote(String, attribution: String)
        case image(Art, caption: String)
    }

    let dek: String
    let readTime: String
    let lede: String
    let blocks: [Block]
    let shop: [Pairing]
    let storeArea: String
    let storeHours: String
}

extension Story {
    var article: StoryArticle { EditorialData.articles[brand] ?? EditorialData.placeholderArticle(for: self) }
}

struct Product: Identifiable {
    var id: String { name }
    let name: String
    let brand: String
    let mark: String
    let category: String
    let isNew: Bool
    let art: Art
}

/// A piece that completes a look with a staple.
struct Pairing: Identifiable {
    var id: String { name }
    let name: String
    let brand: String
    let art: Art
}

struct Staple: Identifiable {
    var id: String { title }
    let title: String
    let subtitle: String
    let thumb: Art
    let pairs: [Pairing]
    let looks: [Art]
}

struct Hotspot: Identifiable {
    let id = UUID()
    let x: CGFloat
    let y: CGFloat
    let item: String
    let price: String
}

struct Look: Identifiable {
    var id: String { title }
    let title: String
    let art: Art
    let spots: [Hotspot]

    /// Everything you can buy for one tagged piece: the exact item first, then similar options.
    func options(for spot: Hotspot) -> [LookSku] {
        let exact = LookSku(name: spot.item, brand: EditorialData.lookItemBrands[spot.item] ?? "District edit",
                            price: spot.price, art: art, focus: UnitPoint(x: spot.x, y: spot.y), zoom: 2.4, isExact: true)
        let similar = (EditorialData.lookAlternatives[spot.item] ?? []).map {
            LookSku(name: $0.name, brand: $0.brand, price: $0.price, art: Art($0.image, art.hexes, seed: 700),
                    focus: $0.focus, zoom: $0.zoom, isExact: false)
        }
        return [exact] + similar
    }
}

/// One buyable option for a tagged piece in a look. `focus` and `zoom` crop the photo to the item.
struct LookSku: Identifiable {
    var id: String { "\(brand)-\(name)" }
    let name: String
    let brand: String
    let price: String
    let art: Art
    let focus: UnitPoint
    let zoom: CGFloat
    let isExact: Bool

    /// The option as a product, for the product page.
    var product: Product {
        Product(name: name, brand: brand, mark: brand.uppercased(), category: "Shop the look", isNew: false, art: art)
    }
}

struct Plan: Identifiable {
    var id: String { title }
    let title: String
    /// Headline broken into display lines.
    let lines: [String]
    let cards: [Art]

    /// Every look in this plan's collection (cover cards first).
    var gallery: [Art] {
        let extra = (EditorialData.planGalleries[title] ?? []).enumerated().map { i, name in
            Art(name, cards.first?.hexes ?? [0x333333, 0x666666], seed: 900 + i)
        }
        return cards + extra
    }

    var count: Int { gallery.count }

    /// Gallery looks paired with their product name and brand, for the feed captions.
    var looks: [FeedLook] {
        let names = EditorialData.planLookNames[title] ?? []
        return gallery.enumerated().map { i, art in
            let entry = i < names.count ? names[i] : (name: "Look \(i + 1)", brand: "District edit")
            return FeedLook(art: art, name: entry.name, brand: entry.brand)
        }
    }
}

/// A look with its caption, as shown in the plan and palette feeds.
struct FeedLook {
    let art: Art
    let name: String
    let brand: String
}

struct Palette: Identifiable {
    let id: String
    let name: String
    let hexes: [UInt32]
    /// One name per colour in `hexes`.
    let shades: [String]

    var looks: [Art] {
        let symbols = ["figure.stand", "figure.walk", "figure.wave", "figure.stand", "figure.walk"]
        let n = hexes.count
        return (0..<6).map { i in
            Art(
                "palette_\(id)_\(i + 1)",
                [hexes[i % n], hexes[(i + 1) % n], hexes[(i + 2) % n]],
                symbol: symbols[i % symbols.count],
                seed: 100 + i * 13 + id.count
            )
        }
    }

    /// Looks paired with their product name and brand, for the feed captions.
    var feed: [FeedLook] {
        let names = EditorialData.paletteLookNames[id] ?? []
        return looks.enumerated().map { i, art in
            let entry = i < names.count ? names[i] : (name: "Look \(i + 1)", brand: "District edit")
            return FeedLook(art: art, name: entry.name, brand: entry.brand)
        }
    }
}

enum EditorialData {
    static let stories: [Story] = [
        Story(brand: "Gully Labs", mark: "गली\nLABS", title: "Every stitch, still by hand",
              art: Art("story_gully_labs", [0x2A1408, 0x7A3E16, 0xC7853F], symbol: "scissors", seed: 11)),
        Story(brand: "Cord", mark: "CORD", title: "What ties a look together",
              art: Art("story_cord", [0x1F140E, 0x6B4428, 0xD8C2A0], symbol: "person.2.fill", seed: 23)),
        Story(brand: "Project Qaafi", mark: "qaafi", title: "Handcream made to perfection, a read",
              art: Art("story_qaafi", [0x3A0606, 0x8F1414, 0xD2402F], symbol: "drop.fill", seed: 37)),
        Story(brand: "Nappa Dori", mark: "ND", title: "Built like it still has a train to catch",
              art: Art("story_nappa_dori", [0x0E0E0E, 0x4A4A4A, 0xB9B9B9], symbol: "suitcase.rolling.fill", seed: 41)),
        Story(brand: "Doodlage", mark: "DOOD\nLAGE", title: "Waste not, wear well",
              art: Art("story_doodlage", [0x1C2414, 0x4F6136, 0xB9C48A], symbol: "leaf.fill", seed: 53)),
    ]

    // Placeholder editorial copy. Written to be brand-safe (no invented founders, dates or quotes);
    // replace with commissioned stories before release.
    static let articles: [String: StoryArticle] = [
        "Gully Labs": StoryArticle(
            dek: "A sneaker label that still believes the best tool in the workshop is a pair of hands.",
            readTime: "6 min read",
            lede: "Walk into the workshop and the first thing you notice is the sound: not machines, but the soft pull of thread through suede, again and again, until it becomes a rhythm.",
            blocks: [
                .paragraph("Every pair starts as a flat sheet of leather and a chalk outline. From there it is cut, skived, punched and stitched — slowly, deliberately, by people who have done this long enough that their hands move before they think."),
                .paragraph("The designs borrow from the street: court shoes, runners, the beaten-in trainers you see on every corner. But the finish is closer to a tailor’s than a factory’s. Edges are burnished. Stitch lines are straight enough to rule a page."),
                .image(Art("article_gully_1", [0x8A5A2B, 0xE0A23A], seed: 801), caption: "Suede, cut and finished by hand before it ever meets a sole."),
                .heading("Made slower, on purpose"),
                .paragraph("Handwork means fewer pairs. It also means each one carries small differences — a stitch that sits a millimetre left, a panel with a deeper nap. The studio calls those signatures, not flaws."),
                .quote("If a machine can make it perfect, we’d rather make it personal.", attribution: "The Gully Labs studio"),
                .paragraph("It is a slower way to build a shoe, and a quieter way to sell one. No hype drops, no countdowns — just a pair that gets better the longer you wear it."),
                .image(Art("article_gully_2", [0x5C1020, 0xE5AC48], seed: 802), caption: "Low-tops, finished in the studio’s signature suede."),
            ],
            shop: [
                Pairing(name: "Suede court sneaker", brand: "Gully Labs", art: Art("article_gully_1", [0x8A5A2B, 0xE0A23A], seed: 801)),
                Pairing(name: "Canvas low-top", brand: "Gully Labs", art: Art("article_gully_2", [0x5C1020, 0xE5AC48], seed: 802)),
                Pairing(name: "Hand-stitched runner", brand: "Gully Labs", art: Art("article_gully_3", [0x7A1A12, 0xC8402F], seed: 803)),
            ],
            storeArea: "Cyberhub, DLF Phase 2, Gurugram",
            storeHours: "Open today till 10 pm"
        ),
        "Cord": StoryArticle(
            dek: "On belts, buckles and the small finishing touch that pulls an outfit into shape.",
            readTime: "4 min read",
            lede: "Some pieces shout. Cord’s pieces hold things together — literally. A cinched waist, a knotted strap, a belt that turns a loose shape into a silhouette.",
            blocks: [
                .paragraph("The label works in earthy, sun-faded colours: rust, mustard, clay, tobacco. Fabrics are soft enough to drape and sturdy enough to keep their line through a long day."),
                .image(Art("article_cord_1", [0xD9A5A0, 0x3A2A22], seed: 811), caption: "A belted coat, worn loose until the buckle decides otherwise."),
                .heading("The finishing touch"),
                .paragraph("Look closely and most designs hinge on one detail — a tie, a strap, a fastening placed exactly where your eye lands. Take it away and the piece is fine. Leave it in and the whole outfit clicks."),
                .quote("Style is mostly a question of where you pull the string.", attribution: "The District Style Desk"),
                .paragraph("Wear it with denim on a weekday, with heels on a weekend, or with nothing but confidence and a good pair of sunglasses."),
                .image(Art("article_cord_2", [0xE8E2D0, 0x8C4F3F], seed: 812), caption: "Knits in the label’s sun-washed palette."),
            ],
            shop: [
                Pairing(name: "Belted trench", brand: "Cord", art: Art("article_cord_1", [0xD9A5A0, 0x3A2A22], seed: 811)),
                Pairing(name: "Relaxed wrap top", brand: "Cord", art: Art("story_cord", [0x6B4428, 0xD8C2A0], seed: 23)),
                Pairing(name: "Soft knit cardigan", brand: "Cord", art: Art("article_cord_2", [0xE8E2D0, 0x8C4F3F], seed: 812)),
            ],
            storeArea: "Galleria Market, Gurugram",
            storeHours: "Open today till 9 pm"
        ),
        "Project Qaafi": StoryArticle(
            dek: "A hand cream in an aluminium tube, and the case for making one small thing very well.",
            readTime: "5 min read",
            lede: "It comes in a crimped metal tube that dents a little more every time you use it. That is the point: an object that records your days, the way a good leather bag does.",
            blocks: [
                .paragraph("Project Qaafi makes very few things, and it treats each one like a flagship. The hand cream is rich without being greasy, absorbs fast, and leaves a scent that is closer to a memory than a perfume."),
                .heading("Fragrance as a story"),
                .paragraph("Each blend is built around notes you would recognise from home — warm wood, something smoky, something green. It is meant to be noticed by you, not announced to a room."),
                .quote("We wanted something you reach for without thinking, and miss when it runs out.", attribution: "The Project Qaafi studio"),
                .image(Art("article_qaafi_1", [0xE8E2D0, 0x8C4F3F], seed: 821), caption: "The everyday ritual, pared back."),
                .paragraph("Pocket it, keep it by the desk, leave it by the door. The tube will tell you how often you did."),
            ],
            shop: [
                Pairing(name: "The Hand Cream", brand: "Project Qaafi", art: Art("story_qaafi", [0x8F1414, 0xD2402F], seed: 37)),
            ],
            storeArea: "Ambience Mall, Gurugram",
            storeHours: "Open today till 10 pm"
        ),
        "Nappa Dori": StoryArticle(
            dek: "Trunks, bags and travel goods built with the old-world romance of a railway platform.",
            readTime: "7 min read",
            lede: "There is a particular kind of luggage that belongs on a station platform at dawn: hard-cornered, brass-latched, carried by someone who knows exactly where they are going.",
            blocks: [
                .paragraph("Nappa Dori’s pieces borrow that romance and make it practical. Structured trunks sit alongside soft weekenders, everyday backpacks and the kind of wallet that gets better with every year in a back pocket."),
                .image(Art("article_nappa_1", [0x8C4F3F, 0xF1E4D8], seed: 831), caption: "Leather that softens and darkens with use."),
                .heading("Built for the journey"),
                .paragraph("Hardware is chunky and honest. Leather is chosen to age rather than stay pristine. The design language is part heritage, part city — as at home on an airport carousel as on a commuter train."),
                .quote("A good bag should look better at the end of the trip than at the start.", attribution: "The District Style Desk"),
                .paragraph("Pack light, pack heavy, pack in a hurry. These are built for all three."),
                .image(Art("article_nappa_2", [0x5C3A1E, 0xC49A6C], seed: 832), caption: "Finishing details, made to be handled."),
            ],
            shop: [
                Pairing(name: "Leather backpack", brand: "Nappa Dori", art: Art("article_nappa_1", [0x8C4F3F, 0xF1E4D8], seed: 831)),
                Pairing(name: "Heritage trunk", brand: "Nappa Dori", art: Art("story_nappa_dori", [0x4A4A4A, 0xB9B9B9], seed: 41)),
            ],
            storeArea: "DLF Promenade, Vasant Kunj",
            storeHours: "Open today till 9:30 pm"
        ),
        "Doodlage": StoryArticle(
            dek: "Fashion made from what the industry throws away — and made to look like it never did.",
            readTime: "5 min read",
            lede: "Every season, the fashion business leaves behind mountains of offcuts and surplus fabric. Doodlage starts there, and works backwards towards something beautiful.",
            blocks: [
                .paragraph("Panels are pieced together from leftover rolls, so no two garments are quite alike. The patchwork is the design, not a disguise."),
                .image(Art("article_doodlage_1", [0xE8E2D0, 0x9FAF90], seed: 841), caption: "Small batches, pieced from surplus fabric."),
                .heading("Waste not"),
                .paragraph("The label keeps runs small, reuses what it can, and designs pieces meant to stay in a wardrobe for years rather than a season."),
                .quote("The most sustainable garment is the one you keep wearing.", attribution: "The District Style Desk"),
                .image(Art("article_doodlage_2", [0x9FB6C9, 0xF4EEE2], seed: 842), caption: "Easy shirts, cut from rescued cotton."),
                .paragraph("It is fashion with a conscience that never asks you to sacrifice the fun part."),
            ],
            shop: [
                Pairing(name: "Patchwork shirt", brand: "Doodlage", art: Art("article_doodlage_2", [0x9FB6C9, 0xF4EEE2], seed: 842)),
                Pairing(name: "Embroidered crop top", brand: "Doodlage", art: Art("article_doodlage_3", [0xF4EEE2, 0x9FAF90], seed: 843)),
                Pairing(name: "Pieced linen set", brand: "Doodlage", art: Art("article_doodlage_1", [0xE8E2D0, 0x9FAF90], seed: 841)),
            ],
            storeArea: "Sector 29, Gurugram",
            storeHours: "Open today till 9 pm"
        ),
    ]

    static func placeholderArticle(for story: Story) -> StoryArticle {
        StoryArticle(dek: "", readTime: "3 min read", lede: story.title, blocks: [], shop: [],
                     storeArea: "Gurugram", storeHours: "Open today")
    }


    // MARK: Product detail (placeholder copy; replace with catalogue data)

    struct ProductDetail {
        let description: String
        let material: String
        let fit: String
        let care: String
    }

    static let productDetails: [String: ProductDetail] = [
        "Cocoa fit-and-flare dress": ProductDetail(
            description: "A sleeveless mini with a fitted, seamed bodice and a full skirt, in a deep cocoa brown.",
            material: "Cotton blend", fit: "Fitted bodice, flared skirt", care: "Machine wash cold"),
        "Acid-wash pinafore dress": ProductDetail(
            description: "A grey acid-wash denim pinafore with a buttoned front. Layer it over knits all winter.",
            material: "100% cotton denim", fit: "Straight, above the knee", care: "Machine wash cold, inside out"),
        "Patchwork denim co-ord": ProductDetail(
            description: "An oversized jacket and wide-leg jeans patched with bright colour blocks. Loud together, easy apart.",
            material: "100% cotton denim", fit: "Oversized jacket, wide leg", care: "Machine wash cold, inside out"),
        "Scarlet wool overcoat": ProductDetail(
            description: "A long, softly tailored overcoat in a colour that does the talking. Throw it over anything.",
            material: "Wool blend", fit: "Relaxed, mid-calf length", care: "Dry clean only"),
        "Sunburst track set": ProductDetail(
            description: "A gold-and-white track set with heritage stripes and popper-side trousers. Wear it together or break it up.",
            material: "Recycled polyester", fit: "Regular jacket, wide-leg trousers", care: "Machine wash cold"),
        "Cream tailored blazer": ProductDetail(
            description: "Sharp shoulders, a single button and a cream shade that goes with everything you own.",
            material: "Viscose blend", fit: "Tailored, hip length", care: "Dry clean recommended"),
        "Denim trucker jacket": ProductDetail(
            description: "The classic trucker in a mid wash, cut a little boxier for layering over hoodies.",
            material: "100% cotton denim", fit: "Boxy, cropped at the hip", care: "Wash inside out, cold"),
        "Marigold kaftan dress": ProductDetail(
            description: "A flowing kaftan in festive marigold with mirror-work detailing at the neckline.",
            material: "Cotton silk", fit: "Relaxed, floor length", care: "Gentle hand wash"),
        "Washed leather biker": ProductDetail(
            description: "A broken-in biker with a soft wash, asymmetric zip and just enough attitude.",
            material: "Lambskin leather", fit: "Regular, hip length", care: "Specialist leather clean"),
        "Patchwork mom jeans": ProductDetail(
            description: "High-rise mom jeans with patchwork panels and a relaxed, tapered leg.",
            material: "Rigid cotton denim", fit: "High rise, tapered", care: "Wash inside out, cold"),
        "Lucky cat graphic tee": ProductDetail(
            description: "A heavyweight tee with an oversized lucky-cat print. Boxy, soft and made to be worn often.",
            material: "Heavyweight cotton", fit: "Oversized, drop shoulder", care: "Machine wash cold"),
    ]

    static let storeAreas: [String: String] = [
        "H&M": "Cyberhub, DLF Phase 2", "adidas": "Ambience Mall", "Zara": "Cyberhub, DLF Phase 2",
        "Blu": "Galleria Market", "Nicobar": "Ambience Mall", "Snitch": "Sector 29",
        "Bonkers Corner": "Cyberhub, DLF Phase 2", "The Souled Store": "Galleria Market",
    ]

    static let products: [Product] = [
        Product(name: "Scarlet wool overcoat", brand: "H&M", mark: "H&M",
                category: "Outerwear", isNew: false, art: Art("rack_hm_overcoat", [0x7A1A12, 0xC8402F, 0xE9D8C8], seed: 3)),
        Product(name: "Sunburst track set", brand: "adidas", mark: "adidas",
                category: "Streetwear", isNew: true, art: Art("rack_adidas_popper", [0xB97A22, 0xE5AC48, 0xF5E2B6], symbol: "figure.walk", seed: 5)),
        Product(name: "Cocoa fit-and-flare dress", brand: "Zara", mark: "ZARA",
                category: "Dresses", isNew: true, art: Art("rack_zara_dress", [0x3B2219, 0x5A3426, 0xDCE8E6], seed: 8)),
        Product(name: "Acid-wash pinafore dress", brand: "Blu", mark: "blu",
                category: "Denim", isNew: false, art: Art("rack_blu_pinafore", [0x3A3A3C, 0xC98E9A, 0xEDEDED], seed: 13)),
        Product(name: "Patchwork denim co-ord", brand: "Bonkers Corner", mark: "BNKR",
                category: "Denim", isNew: true, art: Art("rack_bonkers_patchwork", [0x3E6A9E, 0xE0407A, 0xF2C94C], symbol: "figure.walk", seed: 29)),
        Product(name: "Marigold kaftan dress", brand: "Nicobar", mark: "NICO\nBAR",
                category: "Ethnic", isNew: false, art: Art("rack_nicobar_kaftan", [0xF2E7D3, 0xE0A23A, 0x6A3D24], seed: 17)),
        Product(name: "Washed leather biker", brand: "Snitch", mark: "SNI\nTCH",
                category: "Outerwear", isNew: false, art: Art("rack_snitch_biker", [0x151515, 0x3A2A21, 0x8A5A3B], seed: 19)),
        Product(name: "Lucky cat graphic tee", brand: "The Souled Store", mark: "TSS",
                category: "Streetwear", isNew: false, art: Art("rack_tss_tee", [0xE9E2D4, 0x2D4FA8, 0xEDEDED], symbol: "tshirt.fill", seed: 31)),
    ]

    static let staples: [Staple] = [
        Staple(title: "White tee", subtitle: "Never goes out of style",
               thumb: Art("staple_white_tee", [0xF4F4F4, 0xBDBDBD], symbol: "tshirt.fill", seed: 2),
               pairs: [
                   Pairing(name: "Patchwork mom jeans", brand: "Bonkers Corner", art: Art("rack_bonkers_jeans", [0x1D2A3A, 0x3E5C7E], seed: 29)),
                   Pairing(name: "Washed leather biker", brand: "Snitch", art: Art("rack_snitch_biker", [0x151515, 0x8A5A3B], seed: 19)),
                   Pairing(name: "Cream tailored blazer", brand: "Zara", art: Art("rack_zara_blazer", [0xF0F2F4, 0x3A2C25], seed: 8)),
                   Pairing(name: "Gingham trench", brand: "Cord", art: Art("look_parisian_edge", [0x2A1A14, 0x9C6B4F], seed: 67)),
               ],
               looks: looks("staple_white_tee", [[0xD9D6D0, 0x8C8A86], [0x2B2B2B, 0x6C6C6C], [0xBFB8AC, 0x4F4A44]], count: 6, seed: 200)),
        Staple(title: "Straight denim", subtitle: "The one pair that does it all",
               thumb: Art("staple_denim", [0x5D7FA6, 0x1E3350], symbol: "figure.walk", seed: 4),
               pairs: [
                   Pairing(name: "Lucky cat graphic tee", brand: "The Souled Store", art: Art("rack_tss_tee", [0xE9E2D4, 0x2D4FA8], seed: 31)),
                   Pairing(name: "Cable-knit vest", brand: "Cord", art: Art("look_quiet_luxury", [0xC9B79A, 0xEFE6D6], seed: 61)),
                   Pairing(name: "Scarlet wool overcoat", brand: "H&M", art: Art("rack_hm_overcoat", [0x7A1A12, 0xC8402F], seed: 3)),
                   Pairing(name: "Longline camel coat", brand: "Zara", art: Art("look_camel_coat", [0xC49A6C, 0xE9E5DC], seed: 73)),
               ],
               looks: looks("staple_denim", [[0xA9BCD0, 0x3E5C7E], [0xE7DFD2, 0x5D7FA6], [0x1E3350, 0x0F1A2A]], count: 4, seed: 300)),
        Staple(title: "Sharp blazer", subtitle: "Boardroom to bar, no change",
               thumb: Art("staple_blazer", [0x3A3A3A, 0x0D0D0D], symbol: "figure.stand", seed: 6),
               pairs: [
                   Pairing(name: "The white tee", brand: "H&M", art: Art("staple_white_tee", [0xF4F4F4, 0xBDBDBD], seed: 2)),
                   Pairing(name: "Straight denim", brand: "Bonkers Corner", art: Art("staple_denim", [0x5D7FA6, 0x1E3350], seed: 4)),
                   Pairing(name: "Corduroy shirt dress", brand: "Nicobar", art: Art("look_burgundy_muse", [0x5E1420, 0xC9A99A], seed: 71)),
               ],
               looks: looks("staple_blazer", [[0xC9C2B6, 0x2A2826], [0x5A2830, 0x140A0C], [0xE9E4DA, 0x1A1A1A]], count: 3, seed: 400)),
    ]

    static let looks: [Look] = [
        Look(title: "The Quiet Luxury", art: Art("look_quiet_luxury", [0x6B5A45, 0xC9B79A, 0xEFE6D6], seed: 61), spots: [
            Hotspot(x: 0.6, y: 0.33, item: "Gold huggie hoops", price: "₹1,190"),
            Hotspot(x: 0.48, y: 0.52, item: "Cable-knit vest", price: "₹2,890"),
            Hotspot(x: 0.62, y: 0.76, item: "Light-wash mom jeans", price: "₹2,450"),
        ]),
        Look(title: "The Parisian Edge", art: Art("look_parisian_edge", [0x2A1A14, 0x5B2E22, 0x9C6B4F], symbol: "figure.walk", seed: 67), spots: [
            Hotspot(x: 0.5, y: 0.31, item: "Cat-eye shades", price: "₹1,490"),
            Hotspot(x: 0.64, y: 0.4, item: "Oversized hoops", price: "₹890"),
            Hotspot(x: 0.56, y: 0.64, item: "Gingham trench", price: "₹6,999"),
        ]),
        Look(title: "The Burgundy Muse", art: Art("look_burgundy_muse", [0x1E0A0C, 0x5E1420, 0xC9A99A], seed: 71), spots: [
            Hotspot(x: 0.56, y: 0.3, item: "Mandarin-collar shirt", price: "₹2,490"),
            Hotspot(x: 0.76, y: 0.41, item: "Gold cuff", price: "₹1,650"),
            Hotspot(x: 0.5, y: 0.64, item: "Corduroy shirt dress", price: "₹4,250"),
        ]),
        Look(title: "The Camel Coat", art: Art("look_camel_coat", [0x3B4048, 0xC49A6C, 0xE9E5DC], seed: 73), spots: [
            Hotspot(x: 0.48, y: 0.46, item: "Mini box bag", price: "₹2,950"),
            Hotspot(x: 0.7, y: 0.4, item: "Longline camel coat", price: "₹8,490"),
            Hotspot(x: 0.5, y: 0.7, item: "White skinny jeans", price: "₹2,290"),
        ]),
    ]

    /// Brand of the exact piece in each look. Placeholder until catalogue data lands.
    static let lookItemBrands: [String: String] = [
        "Gold huggie hoops": "Nicobar", "Cable-knit vest": "Cord", "Light-wash mom jeans": "Bonkers Corner",
        "Cat-eye shades": "Zara", "Oversized hoops": "H&M", "Gingham trench": "Cord",
        "Mandarin-collar shirt": "Nicobar", "Gold cuff": "Nicobar", "Corduroy shirt dress": "Nicobar",
        "Mini box bag": "Nappa Dori", "Longline camel coat": "Zara", "White skinny jeans": "Blu",
    ]

    /// Similar options per tagged piece. Placeholder SKUs; photos are crops from the shoot library.
    static let lookAlternatives: [String: [(name: String, brand: String, price: String, image: String, focus: UnitPoint, zoom: CGFloat)]] = [
        "Gold huggie hoops": [
            ("Twisted gold hoops", "Cord", "₹1,450", "look_parisian_edge", UnitPoint(x: 0.64, y: 0.4), 2.4),
            ("Gold ear cuff", "Doodlage", "₹790", "look_burgundy_muse", UnitPoint(x: 0.6, y: 0.3), 2.4),
        ],
        "Cable-knit vest": [
            ("Cream cable cardigan", "Doodlage", "₹3,190", "palette_sage-linen_2", .center, 1),
            ("Ribbed knit vest", "Snitch", "₹1,899", "palette_butter-denim_2", .center, 1),
            ("Argyle sweater vest", "H&M", "₹1,999", "palette_rose-clay_6", .center, 1),
        ],
        "Light-wash mom jeans": [
            ("Patchwork mom jeans", "Bonkers Corner", "₹2,199", "rack_bonkers_jeans", .center, 1),
            ("Straight-leg jeans", "Blu", "₹2,599", "staple_denim", .center, 1),
            ("Wide-leg jeans", "Butter & Denim", "₹2,890", "staple_denim_2", .center, 1),
        ],
        "Cat-eye shades": [
            ("Tortoiseshell frames", "Cord", "₹1,290", "look_quiet_luxury", UnitPoint(x: 0.58, y: 0.28), 2.4),
            ("Oval sunglasses", "H&M", "₹999", "look_camel_coat", UnitPoint(x: 0.55, y: 0.25), 2.4),
        ],
        "Oversized hoops": [
            ("Gold huggie hoops", "Nicobar", "₹1,190", "look_quiet_luxury", UnitPoint(x: 0.6, y: 0.33), 2.4),
            ("Chunky silver hoops", "Snitch", "₹699", "look_burgundy_muse", UnitPoint(x: 0.62, y: 0.32), 2.4),
        ],
        "Gingham trench": [
            ("Scarlet wool overcoat", "H&M", "₹5,999", "rack_hm_overcoat", .center, 1),
            ("Longline camel coat", "Zara", "₹8,490", "look_camel_coat", UnitPoint(x: 0.6, y: 0.5), 1.4),
            ("Belted trench", "Cord", "₹7,250", "article_cord_1", .center, 1),
        ],
        "Mandarin-collar shirt": [
            ("Band-collar linen shirt", "Doodlage", "₹2,190", "palette_sage-linen_1", .center, 1),
            ("Silk mandarin blouse", "Cord", "₹3,450", "plan_office_2", .center, 1),
        ],
        "Gold cuff": [
            ("Hammered gold bangle", "Nicobar", "₹1,890", "look_quiet_luxury", UnitPoint(x: 0.5, y: 0.6), 2.4),
            ("Twisted brass cuff", "Doodlage", "₹1,150", "look_camel_coat", UnitPoint(x: 0.45, y: 0.55), 2.4),
        ],
        "Corduroy shirt dress": [
            ("Marigold kaftan dress", "Nicobar", "₹4,950", "rack_nicobar_kaftan", .center, 1),
            ("Satin slip dress", "Cord", "₹3,290", "plan_first_date_1", .center, 1),
            ("Burgundy wrap midi", "Doodlage", "₹3,890", "plan_wedding_2", .center, 1),
        ],
        "Mini box bag": [
            ("Structured top-handle bag", "Nappa Dori", "₹3,450", "article_nappa_2", .center, 1),
            ("Leather crossbody", "Nappa Dori", "₹2,750", "article_nappa_1", .center, 1),
        ],
        "Longline camel coat": [
            ("Scarlet wool overcoat", "H&M", "₹5,999", "rack_hm_overcoat", .center, 1),
            ("Cream tailored blazer", "Zara", "₹4,290", "rack_zara_blazer", .center, 1),
            ("Oversized check blazer", "Cord", "₹5,490", "staple_blazer_1", .center, 1),
        ],
        "White skinny jeans": [
            ("Straight-leg jeans", "Blu", "₹2,599", "staple_denim", .center, 1),
            ("Ecru wide-leg jeans", "Butter & Denim", "₹2,990", "staple_denim_3", .center, 1),
            ("Patchwork mom jeans", "Bonkers Corner", "₹2,199", "rack_bonkers_jeans", .center, 1),
        ],
    ]

    static let plans: [Plan] = [
        Plan(title: "Date night", lines: ["date night"],
             cards: looks("plan_first_date", [[0x1A1A1A, 0x8C2F39], [0x2B1E2E, 0xD08A8A], [0x101820, 0xC9B79A]], count: 3, seed: 520)),
        Plan(title: "Activewear", lines: ["activewear"],
             cards: looks("plan_active", [[0x1E3350, 0x86B6DE], [0x9FB6C9, 0xF4EEE2], [0x7A1A12, 0xE5AC48]], count: 3, seed: 550)),
        Plan(title: "Diwali parties", lines: ["diwali", "parties"],
             cards: looks("plan_diwali", [[0x3A0E12, 0xC8963E], [0x1F1A12, 0xD9B45A], [0x5C1020, 0xF2D49B]], count: 3, seed: 500)),
        Plan(title: "Sunday brunch", lines: ["sunday", "brunch"],
             cards: looks("plan_brunch", [[0xF2E2B8, 0xC98B5B], [0x9FB6C9, 0xF4EEE2], [0xE8C7A0, 0x6E8B5A]], count: 3, seed: 510)),
        Plan(title: "Wedding guest", lines: ["wedding", "guest"],
             cards: looks("plan_wedding", [[0x6B1E3A, 0xE9B4C2], [0x1E4A3A, 0xD9C27A], [0xC75B2A, 0xF6D8A8]], count: 3, seed: 530)),
        Plan(title: "Office to after-hours", lines: ["office to", "after-hours"],
             cards: looks("plan_office", [[0x2A2D33, 0xA9AEB5], [0x3A2A22, 0xD8C6B0], [0x111111, 0x5A5F66]], count: 3, seed: 540)),
    ]

    /// Extra looks per plan, drawn from the shoot library (reused photography until a real shoot lands).
    static let planGalleries: [String: [String]] = [
        "Date night": ["look_burgundy_muse", "plan_wedding_2", "palette_rose-clay_5", "rack_zara_blazer", "look_parisian_edge"],
        "Activewear": ["rack_adidas_track", "palette_butter-denim_6", "staple_white_tee_2", "rack_tss_tee", "palette_slate-noir_2"],
        "Diwali parties": ["rack_nicobar_kaftan", "plan_wedding_1", "plan_wedding_3", "look_burgundy_muse", "palette_rose-clay_3"],
        "Sunday brunch": ["palette_butter-denim_1", "palette_sage-linen_2", "staple_white_tee_1", "palette_rose-clay_6", "look_quiet_luxury"],
        "Wedding guest": ["plan_diwali_3", "rack_nicobar_kaftan", "plan_diwali_1", "look_burgundy_muse", "palette_rose-clay_1"],
        "Office to after-hours": ["staple_blazer_1", "staple_blazer_2", "staple_blazer_3", "rack_zara_blazer", "look_camel_coat"],
    ]

    /// Caption per gallery look (same order as `Plan.gallery`). Placeholder SKUs until catalogue data lands.
    static let planLookNames: [String: [(name: String, brand: String)]] = [
        "Date night": [
            ("Satin slip dress", "Cord"), ("Cropped leather jacket", "Nappa Dori"), ("Silk camisole", "Cord"),
            ("Burgundy wrap midi", "Doodlage"), ("Draped satin gown", "Nicobar"), ("Rose linen co-ord", "Doodlage"),
            ("Sharp black blazer", "Zara"), ("Striped Breton top", "Cord"),
        ],
        "Activewear": [
            ("Seamless sports bra", "Adidas"), ("Track jacket", "Adidas"), ("High-rise leggings", "Adidas"),
            ("Retro track top", "Adidas"), ("Relaxed denim shorts", "Butter & Denim"), ("Oversized white tee", "The Souled Store"),
            ("Graphic boxy tee", "The Souled Store"), ("Slate zip hoodie", "Gully Labs"),
        ],
        "Diwali parties": [
            ("Gold tissue kurta", "Nicobar"), ("Mirror-work lehenga", "Doodlage"), ("Brocade bandhgala", "Nicobar"),
            ("Printed silk kaftan", "Nicobar"), ("Embroidered anarkali", "Cord"), ("Zari border saree", "Nicobar"),
            ("Burgundy wrap midi", "Doodlage"), ("Clay silk co-ord", "Cord"),
        ],
        "Sunday brunch": [
            ("Butter linen shirt", "Cord"), ("Gingham sundress", "Doodlage"), ("Straw tote", "Nappa Dori"),
            ("Straight-leg denim", "Butter & Denim"), ("Sage linen set", "Doodlage"), ("Classic white tee", "Cord"),
            ("Rose knit vest", "Doodlage"), ("Camel knit polo", "Cord"),
        ],
        "Wedding guest": [
            ("Pleated organza saree", "Nicobar"), ("Emerald silk kurta set", "Cord"), ("Marigold lehenga", "Doodlage"),
            ("Velvet bandhgala", "Nicobar"), ("Printed silk kaftan", "Nicobar"), ("Gold tissue kurta", "Nicobar"),
            ("Burgundy wrap midi", "Doodlage"), ("Rose clay drape", "Cord"),
        ],
        "Office to after-hours": [
            ("Charcoal wide-leg trousers", "Cord"), ("Camel shirt jacket", "Cord"), ("Black column dress", "Zara"),
            ("Double-breasted blazer", "Zara"), ("Oversized check blazer", "Cord"), ("Cropped tux blazer", "Zara"),
            ("Sharp black blazer", "Zara"), ("Longline camel coat", "Cord"),
        ],
    ]

    static let palettes: [Palette] = [
        Palette(id: "butter-denim", name: "Butter & Denim", hexes: [0x86B6DE, 0x5C3A1E, 0xF6E27A],
                shades: ["Denim", "Cocoa", "Butter"]),
        Palette(id: "slate-noir", name: "Slate Noir", hexes: [0x7C8794, 0x5B4E45, 0x2B211C, 0x5A5632],
                shades: ["Slate", "Taupe", "Espresso", "Moss"]),
        Palette(id: "midnight-olive", name: "Midnight Olive", hexes: [0x2F3E4E, 0x2A1E18, 0x6E625A, 0xA9A47E],
                shades: ["Midnight", "Coffee", "Stone", "Olive"]),
        Palette(id: "rose-clay", name: "Rose Clay", hexes: [0xD9A5A0, 0x8C4F3F, 0xF1E4D8],
                shades: ["Rose", "Clay", "Bone"]),
        Palette(id: "sage-linen", name: "Sage Linen", hexes: [0x9FAF90, 0xE8E2D0, 0x4A5340],
                shades: ["Sage", "Linen", "Fern"]),
    ]

    /// Caption per palette look (same order as `Palette.looks`). Placeholder SKUs until catalogue data lands.
    static let paletteLookNames: [String: [(name: String, brand: String)]] = [
        "butter-denim": [
            ("Light-wash straight jeans", "Butter & Denim"), ("Butter yellow cardigan", "Cord"), ("Denim chore jacket", "Butter & Denim"),
            ("Brown leather loafers", "Nappa Dori"), ("Lemon poplin shirt", "Doodlage"), ("Relaxed denim shorts", "Butter & Denim"),
        ],
        "slate-noir": [
            ("Grey wool overcoat", "Cord"), ("Slate knit crewneck", "Cord"), ("Taupe pleated trousers", "Zara"),
            ("Espresso leather tote", "Nappa Dori"), ("Moss utility jacket", "Gully Labs"), ("Charcoal turtleneck", "Cord"),
        ],
        "midnight-olive": [
            ("Navy double-breasted coat", "Cord"), ("Olive cargo trousers", "Gully Labs"), ("Stone ribbed knit", "Doodlage"),
            ("Coffee suede boots", "Gully Labs"), ("Midnight satin shirt", "Zara"), ("Olive field jacket", "Cord"),
        ],
        "rose-clay": [
            ("Rose linen co-ord", "Doodlage"), ("Clay wrap skirt", "Cord"), ("Blush silk blouse", "Nicobar"),
            ("Terracotta tote", "Nappa Dori"), ("Bone linen trousers", "Doodlage"), ("Dusty pink knit vest", "Cord"),
        ],
        "sage-linen": [
            ("Sage linen shirt", "Doodlage"), ("Linen wide-leg trousers", "Cord"), ("Fern overshirt", "Gully Labs"),
            ("Ecru crochet top", "Doodlage"), ("Sage slip skirt", "Nicobar"), ("Natural linen blazer", "Cord"),
        ],
    ]

    private static func looks(_ prefix: String, _ swatches: [[UInt32]], count: Int, seed: Int) -> [Art] {
        let symbols = ["figure.stand", "figure.walk", "figure.wave"]
        return (0..<count).map { i in
            Art("\(prefix)_\(i + 1)", swatches[i % swatches.count], symbol: symbols[i % symbols.count], seed: seed + i * 7)
        }
    }
}
