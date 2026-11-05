import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// MARK: - Palette

/// Colours from the "Full payment" product-drops Figma (node 7647:7142) that have no Mapped token.
/// They are used only inside the drops flow.
enum DropPalette {
    /// Figma color/text/success.
    static let success = Color(rgba: 0x58E487FF)
    /// Product card hairline.
    static let cardEdge = Color(rgba: 0x999999FF)
    /// Steps rail: surface/primary into a mid grey.
    static let railEnd = Color(rgba: 0x5C5C5CFF)
    static let railGreen = Color(rgba: 0x158E3EFF)
    static let paidGreen = Color(rgba: 0x3CE281FF)
    static let editLink = Color(rgba: 0xC3ACF6FF)
    static let strike = Color(rgba: 0x545459FF)
    static let meta = Color(rgba: 0xA0A0A7FF)
    static let warning = Color(rgba: 0xF09275FF)
    static let summaryBand = Color(rgba: 0x371BA7FF)
    static let reserveEdge = Color(rgba: 0x3597FFFF)
    static let offerGlyphEdge = Color(rgba: 0x231268FF)
    static let giftEdge = Color(rgba: 0x4D47C4FF)
    static let dueRow = Color(rgba: 0x2C2C2E80)
    static let cardTop = Color(rgba: 0x1E1E20FF)
    static let cardFoot = Color(rgba: 0x19191CFF)
    static let ink = Color(rgba: 0x131316FF)
    static let softWhite = Color(rgba: 0xFAFAFAFF)
    static let white70 = Color(rgba: 0xF7F7F7B3)
    static let white50 = Color(rgba: 0xF7F7F780)
    static let genreGold = Color(rgba: 0xB8A91EFF)

    /// "Crazy drops" chrome: bright at the cap line, falling to steel at the baseline.
    static let chrome = LinearGradient(stops: [.init(color: .white, location: 0), .init(color: Color(rgba: 0xF3F3F2FF), location: 0.45),
                                               .init(color: Color(rgba: 0xC5C6C7FF), location: 0.75), .init(color: Color(rgba: 0x8C8C8EFF), location: 1)],
                                       startPoint: .top, endPoint: .bottom)
    /// "Pay 25% now to reserve".
    static let reserveText = RadialGradient(colors: [Color(rgba: 0xCFE0FFFF), Color(rgba: 0x86A2FFFF), Color(rgba: 0x3D64FFFF)],
                                            center: UnitPoint(x: 0.57, y: -1), startRadius: 0, endRadius: 60)
    /// Cart, collection and summary cards.
    static let card = LinearGradient(colors: [cardTop, cardFoot], startPoint: .top, endPoint: .bottom)
}

private typealias P = DropPalette

// MARK: - Model

struct DropProduct: Identifiable, Hashable {
    let id: String
    let name: String
    let brand: String
    let price: Int
    let mrp: Int
    let image: String
    let backdrop: String
    var tag = "Unisex"
    var dots: [String] = []
    var moreColours = 0
    var brandLogo: String?
    /// Each drop sells one way only: reserve with 25%, or pay in full.
    var payment: DropPaymentPlan = .full
    var colours: [DropColour] = []
    /// PDP copy and size run; products without them use the shared defaults in `DropsData`.
    var tagline: String? = nil
    var about: String? = nil
    var sizeRun: [String]? = nil
    /// The card image is a full product photo (fills its tile) rather than a cutout.
    var photoCard = false

    /// Colourways with their photos. A product without listed colours is one SKU; until it has its
    /// own photos it shows its cutout from both sides plus two close-ups (see `DropShotImage`).
    var colourways: [DropColour] {
        colours.isEmpty ? [DropColour(id: "default", name: tag, swatch: image, images: [image, "\(image)#side", "\(image)#toe", "\(image)#heel"])] : colours
    }

    /// Best effective price with the first-purchase coupon (10%) and the HSBC card offer
    /// (15% up to ₹800 on bills above ₹2,000), as on the PDP's "Buy it for" card.
    var bestPrice: (coupon: Int, bank: Int, final: Int) {
        let coupon = Int((Double(price) * 0.10).rounded())
        let afterCoupon = price - coupon
        let bank = afterCoupon >= 2_000 ? min(Int((Double(afterCoupon) * 0.15).rounded()), 800) : 0
        return (coupon, bank, afterCoupon - bank)
    }
}

struct DropColour: Identifiable, Hashable {
    let id: String
    let name: String
    let swatch: String
    /// Every photo of this colourway (SKU), in gallery order.
    var images: [String] = []
}

struct DropStore: Identifiable, Hashable {
    let id: String
    let name: String
    let distance: String
    let area: String
    let offer: String
    let logo: String
    var logoInset = false
    var address = ""
    var km = ""
}

struct DropOffer: Identifiable, Hashable {
    enum Kind { case credit, debit, emi }
    let id: String
    let title: String
    let detail: String
    let logo: String
    let kind: Kind
}

struct DropCartItem: Identifiable, Hashable {
    let id = UUID()
    let product: DropProduct
    var colour: String
    var size: String
    var image: String
    var quantity = 1
}

enum DropPaymentPlan: String {
    case full, reserve
}

enum DropRoute: Hashable {
    case listing
    case product(DropProduct)
    case gallery(DropProduct, colour: String, index: Int)
    case cart
    case offers
    case success
}

/// Content for the drops flow. Products, prices, stores and offers are from the Figma.
enum DropsData {
    static let supernova = DropProduct(id: "supernova", name: "Supernova Ease", brand: "Adidas", price: 59_999, mrp: 69_999,
                                       image: "pd_supernova", backdrop: "pd_blur_supernova", tag: "Men", dots: ["pd_dot_grey", "pd_dot_white"], moreColours: 3,
                                       payment: .reserve)
    static let gelQuantum = DropProduct(id: "gel-quantum", name: "Gel-Quantum 360", brand: "Asics", price: 7_590, mrp: 8_590,
                                        image: "pd_gel_quantum", backdrop: "pd_blur_gel", tag: "Women", dots: ["pd_dot_grey", "pd_dot_white"])
    static let nb9060 = DropProduct(id: "nb-9060", name: "New balance 9060", brand: "New Balance", price: 17_590, mrp: 18_590,
                                    image: "pd_nb9060", backdrop: "pd_blur_nb", brandLogo: "pd_logo_nb")
    static let runNitro = DropProduct(id: "forever-run", name: "Forever runNitro", brand: "Puma", price: 17_590, mrp: 18_590,
                                      image: "pd_runnitro", backdrop: "pd_blur_runnitro", brandLogo: "pd_logo_nb")
    static let speedcat = DropProduct(id: "speedcat", name: "Puma Speedcat", brand: "Puma", price: 9_999, mrp: 10_999,
                                      image: "pd_speedcat", backdrop: "pd_blur_runnitro", dots: ["pd_dot_red", "pd_dot_blue"], moreColours: 3,
                                      payment: .reserve, colours: colours)

    /// PUMA Speedguard, from the PDP Figma (node 7907:34409): yellow on black, shot on a model and close up.
    static let speedguard = DropProduct(
        id: "speedguard", name: "PUMA Speedguard", brand: "Puma", price: 8_999, mrp: 9_999,
        image: "pd_speedguard_yellow", backdrop: "pd_blur_supernova", tag: "Men",
        dots: ["pd_dot_red", "pd_dot_blue"], moreColours: 3, payment: .reserve,
        colours: [
            DropColour(id: "yellow", name: "Yellow on Black", swatch: "pd_speedguard_yellow",
                       images: ["pd_speedguard_model", "pd_speedguard_closeup", "pd_speedguard_yellow"]),
            DropColour(id: "black", name: "Black on White", swatch: "pd_speedguard_black", images: ["pd_speedguard_black"]),
            DropColour(id: "red", name: "Red on White", swatch: "pd_speedguard_red", images: ["pd_speedguard_red"]),
            DropColour(id: "blue", name: "Blue on Pink", swatch: "pd_speedguard_blue", images: ["pd_speedguard_blue"]),
        ],
        tagline: "Check out Puma's vibrant black and yellow shoes—stylish, comfy, and perfect for adding a fun pop to your collection.",
        about: "Engineered for speed and agility, the PUMA Speedguard features a lightweight upper and a responsive midsole for superior performance on the track.",
        sizeRun: ["3", "4", "5", "6", "7", "8", "9", "10", "11", "12"], photoCard: true)

    static let topDeals = [speedguard, supernova, gelQuantum]
    static let sneakers = [nb9060, runNitro]
    /// The Sneakers listing ("Category landing (generic)").
    static let listing: [DropProduct] = [
        speedguard,
        DropProduct(id: "l-supernova", name: "Supernova Ease", brand: "Adidas", price: 17_590, mrp: 18_590, image: "pd_supernova",
                    backdrop: "pd_blur_nb", dots: ["pd_dot_grey", "pd_dot_white"], moreColours: 3),
        DropProduct(id: "l-gel", name: "GEL-Quantum 360", brand: "ASICS", price: 17_590, mrp: 18_590, image: "pd_gel_quantum", backdrop: "pd_blur_runnitro"),
        speedcat,
        DropProduct(id: "l-fuelcell", name: "FuelCell Propel v5", brand: "New Balance", price: 17_590, mrp: 18_590, image: "pd_runnitro", backdrop: "pd_blur_nb"),
        DropProduct(id: "l-adizero", name: "Adizero SL2", brand: "Adidas", price: 17_590, mrp: 18_590, image: "pd_adizero", backdrop: "pd_blur_nb"),
        DropProduct(id: "l-gel1130", name: "GEL-1130", brand: "ASICS", price: 17_590, mrp: 18_590, image: "pd_gel1130", backdrop: "pd_blur_runnitro"),
    ]
    static let crossSell = [nb9060, runNitro, supernova]

    static let colours = [
        DropColour(id: "black", name: "Black-White", swatch: "pd_swatch_black",
                   images: ["pd_speedcat_hero", "pd_gal_side", "pd_gal_pair", "pd_gal_angle", "pd_gal_top", "pd_hot_speedcats"]),
        DropColour(id: "red", name: "Red-white", swatch: "pd_swatch_red", images: ["pd_swatch_red", "pd_blur_runnitro"]),
        DropColour(id: "blue", name: "Blue-Pink", swatch: "pd_swatch_blue", images: ["pd_swatch_blue"]),
    ]
    /// UK sizes with their US, EU and foot-length equivalents for the size guide.
    static let sizeChart = [("6", "7", "39", "24.5"), ("7", "8", "40.5", "25.5"), ("8", "9", "42", "26.5"),
                            ("9", "10", "43", "27.5"), ("10", "11", "44.5", "28.5"), ("11", "12", "46", "29.5")]
    static let sizes = ["6", "7", "8", "9", "10", "11"]
    static let highlights = [("Material", "Synthetic"), ("Sole", "Rubber"), ("Weight", "280g"), ("Fit", "True")]
    static let specs = [("Upper", "Suede with leather Formstrip"), ("Midsole", "Low-profile rubber"), ("Closure", "Lace-up"), ("Origin", "Vietnam")]
    static let description = "Engineered for speed and agility, the PUMA Speedcat Pro features a lightweight upper and a responsive midsole for superior performance on the track."


    static let stores = [
        DropStore(id: "apple", name: "Apple store", distance: "3.9 kms", area: "Select city mall, saket", offer: "Flat ₹300 OFF + Bank benefits",
                  logo: "pd_store_apple", logoInset: true,
                  address: "Select City Mall, District Centre, Sector 6, Pushp Vihar, Saket, New Delhi, Delhi 110017", km: "24 km away"),
        DropStore(id: "imagine-noida", name: "Imagine store", distance: "7 kms", area: "Dlf mall of india, Noida", offer: "Bank benefits",
                  logo: "pd_store_imagine", address: "DLF Mall of India, Sector 18, Noida, Uttar Pradesh 201301", km: "7 km away"),
        DropStore(id: "imagine-gurgaon", name: "Imagine store", distance: "8.2 kms", area: "Cyber hub, gurgaon", offer: "Extra 4% OFF + Bank benefits",
                  logo: "pd_store_imagine", address: "Cyber Hub, DLF Cyber City, Gurugram, Haryana 122002", km: "8.2 km away"),
        DropStore(id: "ivenus", name: "ivenus", distance: "9 kms", area: "Ambience mall, gurgaon", offer: "Extra ₹300 OFF + 3 more offers",
                  logo: "pd_store_ivenus", address: "Ambience Mall, NH-48, Gurugram, Haryana 122002", km: "9 km away"),
    ]
    static let storeBrands = ["All", "Apple store", "vijay sales", "croma", "Ivenus"]

    static let offers = [
        DropOffer(id: "hsbc-1", title: "15% OFF up to ₹800", detail: "On bills above ₹2,000", logo: "pd_bank_hsbc", kind: .credit),
        DropOffer(id: "hdfc-1", title: "10% OFF up to ₹500", detail: "On bills above ₹2,000", logo: "pd_bank_hdfc", kind: .debit),
        DropOffer(id: "hsbc-2", title: "15% OFF up to ₹800", detail: "On bills above ₹2,000", logo: "pd_bank_hsbc", kind: .emi),
        DropOffer(id: "hsbc-3", title: "15% OFF up to ₹800", detail: "On bills above ₹2,000", logo: "pd_bank_hsbc", kind: .credit),
        DropOffer(id: "hdfc-2", title: "10% OFF up to ₹500", detail: "On bills above ₹2,000", logo: "pd_bank_hdfc", kind: .debit),
    ]
}

/// Indian-style grouping: ₹1,27,350.
func rupees(_ value: Int) -> String {
    let digits = String(abs(value))
    guard digits.count > 3 else { return (value < 0 ? "-₹" : "₹") + digits }
    let last3 = digits.suffix(3)
    var head = String(digits.dropLast(3))
    var groups: [String] = []
    while head.count > 2 { groups.insert(String(head.suffix(2)), at: 0); head = String(head.dropLast(2)) }
    if !head.isEmpty { groups.insert(head, at: 0) }
    return (value < 0 ? "-₹" : "₹") + groups.joined(separator: ",") + "," + last3
}

/// Shared state for one run through the drops flow.
@Observable
final class DropFlow {
    var path: [DropRoute] = []
    var cart: [DropCartItem] = []
    var store: DropStore?
    var date = 0
    var time = "10:00 AM"
    var couponApplied = false

    static let dates = [("30 Oct", "Fri"), ("31 Oct", "Sat"), ("1 Nov", "Sun")]
    static let times = ["8:30 AM", "9:00 AM", "9:30 AM", "10:00 AM", "10:30 AM", "11:00 AM"]
    static let unavailable: Set<String> = ["10:30 AM"]

    var slotLabel: String { "\(DropFlow.dates[date].1), \(DropFlow.dates[date].0) • \(time)" }
    var itemTotal: Int { cart.reduce(0) { $0 + $1.product.mrp * $1.quantity } }
    var itemDiscount: Int { cart.reduce(0) { $0 + ($1.product.mrp - $1.product.price) * $1.quantity } }
    var coupon: Int { couponApplied ? 500 : 0 }
    var total: Int { itemTotal - itemDiscount - coupon }
    /// Pay in full now, or reserve with 25% and pay the balance at pick-up.
    var plan: DropPaymentPlan = .reserve
    /// Reserve plan only: whether the balance has since been paid.
    var balancePaid = false
    /// Reserve plan only: identifies the reservation for paying the balance. Never a pickup credential.
    let reservationID = "RSV-48K2"
    /// Issued only once the order is fully paid; the counter hands over the pick against it.
    let pickupCode = "BJF2K1"

    var reserveNow: Int { (Double(total) * 0.25).rounded().toInt }
    var reserveLater: Int { total - reserveNow }
    /// Charged at checkout under the chosen plan.
    var payNow: Int { plan == .full ? total : reserveNow }
    /// Left to pay after checkout.
    var remaining: Int { plan == .full || balancePaid ? 0 : reserveLater }
    var isFullyPaid: Bool { remaining == 0 }
    var savings: Int { itemDiscount + coupon }
}

private extension Double { var toInt: Int { Int(self) } }

// MARK: - Type

extension View {
    /// Be Vietnam Pro at a Figma size that has no named Backstage style (18, 22, 10).
    func dropFont(_ weight: String, _ size: CGFloat, relativeTo style: Font.TextStyle = .body) -> some View {
        font(.custom("BeVietnamPro-\(weight)", size: size, relativeTo: style))
    }

    /// The Figma uppercase section label: Label 2 face (12 Medium), caps. Set directly because
    /// `backstageText` pins `textCase(nil)`.
    func dropSectionLabel() -> some View {
        dropFont("Medium", 12, relativeTo: .subheadline).textCase(.uppercase)
    }
}

// MARK: - Stores banner

/// Stores-tab hero for the product drops, at 786×800 like every page of the banner carousel so the
/// pages are the same height; the copy sits low because the tab header covers the top.
struct ProductDropsBanner: View {
    var action: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(786.0 / 800.0, contentMode: .fit)
            .overlay {
                Image("pd_hot_speedcats")
                    .resizable()
                    .scaledToFill()
            }
            .overlay {
                LinearGradient(stops: [.init(color: .black.opacity(0.55), location: 0), .init(color: .clear, location: 0.3),
                                       .init(color: .clear, location: 0.45), .init(color: P.ink.opacity(0.92), location: 0.82)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { copy }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: R.cornerRadiusCorner24, bottomTrailingRadius: R.cornerRadiusCorner24))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Product drops. Lock in the crazy drops: reserve today's hottest sneakers and pick them up in store")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the drops")
    }

    private var copy: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace8) {
            Text("Product drops")
                .dropFont("Medium", 12)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(M.textPrimary)
            CrazyDropsTitle(size: 40)
            Text("Reserve the hottest sneakers now, pick them up in store.")
                .backstageText(.body3)
                .foregroundStyle(P.white70)
            HStack(spacing: R.spacingSpace4) {
                Text("Explore drops")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .backstageText(.button3)
            .foregroundStyle(M.textInverse)
            .padding(.horizontal, R.spacingSpace16)
            .frame(height: 32)
            .background(M.surfaceInverse, in: Capsule())
            .padding(.top, R.spacingSpace8)
        }
        .padding(R.spacingSpace20)
        .padding(.bottom, R.spacingSpace12)
    }
}

/// Paging banner carousel at the top of the Stores tab, with the PDP-style page pill.
struct StoresBannerCarousel<Page: View>: View {
    let count: Int
    @ViewBuilder let page: (Int) -> Page
    @State private var current: Int? = {
        #if DEBUG
        if let i = ProcessInfo.processInfo.arguments.firstIndex(of: "-bannerPage"), i + 1 < ProcessInfo.processInfo.arguments.count {
            return Int(ProcessInfo.processInfo.arguments[i + 1])
        }
        #endif
        return 0
    }()

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<count, id: \.self) { i in
                    page(i).containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.paging)
        .scrollIndicators(.hidden)
        .scrollPosition(id: $current)
        .overlay(alignment: .bottom) {
            DropPageDots(count: count, current: current ?? 0)
                .padding(.bottom, R.spacingSpace12)
        }
    }
}

/// Figma carousel indicator: a 21×6 active bar and 4.5pt dots in a frosted pill.
struct DropPageDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i == current ? M.textPrimary : Color.white.opacity(0.48))
                    .frame(width: i == current ? 21 : 4.5, height: i == current ? 6 : 4.5)
            }
        }
        .padding(3)
        .background(.ultraThinMaterial.opacity(0.6), in: Capsule())
        .background(Color.black.opacity(0.16), in: Capsule())
        .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: 0.75))
        .animation(.snappy, value: current)
        .accessibilityElement()
        .accessibilityLabel("Page \(current + 1) of \(count)")
    }
}

/// "Crazy drops" in the Figma's chrome finish.
struct CrazyDropsTitle: View {
    var size: CGFloat = 35

    var body: some View {
        Text("Crazy drops")
            .dropFont("SemiBold", size, relativeTo: .largeTitle)
            .tracking(-size * 0.02)
            .foregroundStyle(DropPalette.chrome)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Flow root

/// The product drops flow, built from the Figma section "Full payment" (node 7647:7142): drops
/// landing → Sneakers listing → PDP (with gallery) → store and pick-up slot sheets → cart (with all
/// offers) → payment successful.
struct ProductDropsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var flow = DropFlow()

    var body: some View {
        NavigationStack(path: $flow.path) {
            DropsLandingView(close: { dismiss() })
                .navigationDestination(for: DropRoute.self) { route in
                    Group {
                        switch route {
                        case .listing: DropsListingView()
                        case .product(let product): DropsProductView(product: product)
                        case let .gallery(product, colour, index): DropsGalleryView(product: product, colourID: colour, index: index)
                        case .cart: DropsCartView()
                        case .offers: DropsOffersView()
                        case .success: DropsPaymentSuccessView(close: { dismiss() })
                        }
                    }
                    .toolbar(.hidden, for: .navigationBar)
                }
                .toolbar(.hidden, for: .navigationBar)
        }
        .environment(flow)
        .preferredColorScheme(.dark)
        #if DEBUG
        .onAppear(perform: openDebugRoute)
        #endif
    }

    #if DEBUG
    /// `-dropsRoute listing|product|gallery|cart|offers|success` opens a screen directly in Debug builds.
    private func openDebugRoute() {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-dropsRoute"), i + 1 < args.count, flow.path.isEmpty else { return }
        let p = DropsData.speedcat
        flow.cart = [DropCartItem(product: p, colour: "Black-White", size: "7", image: "pd_speedcat"),
                     DropCartItem(product: p, colour: "Red-white", size: "8", image: "pd_swatch_red")]
        flow.store = DropsData.stores[0]
        if let j = args.firstIndex(of: "-dropsPlan"), j + 1 < args.count, let plan = DropPaymentPlan(rawValue: args[j + 1]) { flow.plan = plan }
        flow.balancePaid = args.contains("-dropsBalancePaid")
        switch args[i + 1] {
        case "listing": flow.path = [.listing]
        case "product": flow.path = [.product(p)]
        case "productFull": flow.path = [.product(DropsData.nb9060)]
        case "speedguard": flow.path = [.product(DropsData.speedguard)]
        case "gallery": flow.path = [.product(p), .gallery(p, colour: "black", index: 0)]
        case "cart": flow.path = [.product(p), .cart]
        case "offers": flow.path = [.product(p), .offers]
        case "success": flow.path = [.product(p), .cart, .success]
        default: break
        }
    }
    #endif
}

/// Identifies the drops flow for `readerCover`.
struct ProductDropsPresentation: Identifiable {
    let id = "product-drops"
}

// MARK: - Shared chrome

/// Back arrow, title and optional subtitle, with an optional trailing action (Figma "Page Headers").
struct DropPageHeader<Trailing: View>: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    var subtitle: String?
    var back: (() -> Void)?
    @ViewBuilder var trailing: () -> Trailing

    init(title: String, subtitle: String? = nil, back: (() -> Void)? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.back = back
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back") { (back ?? { dismiss() })() }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .dropFont("SemiBold", 18, relativeTo: .title3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .accessibilityAddTraits(.isHeader)
                if let subtitle {
                    Text(subtitle)
                        .backstageText(.label2)
                        .foregroundStyle(M.textTertiary)
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            trailing()
        }
        .padding(.leading, R.spacingSpace12)
        .padding(.trailing, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace8)
    }
}

extension DropPageHeader where Trailing == EmptyView {
    init(title: String, subtitle: String? = nil, back: (() -> Void)? = nil) {
        self.init(title: title, subtitle: subtitle, back: back) { EmptyView() }
    }
}

/// Figma pill filter rail chip (32pt, white 8% fill, white border when selected).
struct DropChip: View {
    let title: String
    var selected = false
    var removable = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            HStack(spacing: R.spacingSpace4) {
                Text(title)
                if removable && selected {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .semibold))
                        .accessibilityHidden(true)
                }
            }
            .backstageText(.label2)
            .foregroundStyle(M.textPrimary)
            .padding(.horizontal, R.spacingSpace12)
            .frame(height: 32)
            .background(M.surfaceTransparent, in: Capsule())
            .overlay(Capsule().strokeBorder(selected ? M.borderSelection : M.borderSubtle, lineWidth: R.stroke1Px))
            .frame(minHeight: 44)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// The floating glass CTA dock at the foot of each screen (Figma "CTA" / "Action Card Glass").
struct DropCTADock<Content: View>: View {
    var radius: CGFloat = R.cornerRadiusFullRounded
    @ViewBuilder let content: Content

    var body: some View {
        VStack(spacing: R.spacingSpace12) { content }
            .padding(R.spacingSpace16)
            .background(Color.black.opacity(0.56), in: RoundedRectangle(cornerRadius: min(radius, 36), style: .continuous))
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: min(radius, 36), style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: min(radius, 36), style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            .padding(.horizontal, R.spacingSpace12)
            .padding(.top, R.spacingSpace24)
            .padding(.bottom, R.spacingSpace8)
            .background {
                LinearGradient(colors: [.clear, .black.opacity(0.24)], startPoint: .top, endPoint: .bottom)
                    .background(.ultraThinMaterial.opacity(0.5))
                    .mask(LinearGradient(colors: [.clear, .black, .black], startPoint: .top, endPoint: .bottom))
                    .ignoresSafeArea()
            }
    }
}

/// Strike-through MRP next to a price.
struct DropPrice: View {
    let price: Int
    let mrp: Int
    var priceStyle: BackstageTextStyle = .title4
    var priceColor: Color = DropPalette.success
    var mrpSize: CGFloat = 12

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
            Text(rupees(price))
                .backstageText(priceStyle)
                .foregroundStyle(priceColor)
            Text(rupees(mrp))
                .dropFont("Medium", mrpSize)
                .strikethrough()
                .foregroundStyle(M.textSecondary.opacity(0.6))
                .accessibilityLabel("was \(rupees(mrp))")
        }
    }
}

/// Uppercase section label with an optional "See all >" link.
struct DropSectionHeader: View {
    let title: String
    var seeAll: (() -> Void)?

    var body: some View {
        HStack {
            Text(title)
                .dropSectionLabel()
                .foregroundStyle(M.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            if let seeAll {
                Button(action: seeAll) {
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold))
                    }
                    .backstageText(.button3)
                    .foregroundStyle(M.textPrimary)
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .frame(height: 24)
    }
}

// MARK: - Product card

/// The Figma product card: a frosted tile with a lit product shot, name, brand and price.
/// `scale` 1 is the landing size (223 wide); the listing uses 0.74.
struct DropProductCard: View {
    let product: DropProduct
    var scale: CGFloat = 1
    var showsBrand = true
    var nameStyle: BackstageTextStyle = .title3
    var width: CGFloat?

    private var imageWidth: CGFloat { width.map { $0 - 16 * scale } ?? 206.7 * scale }
    private var imageHeight: CGFloat { imageWidth * 174.8 / 206.7 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10 * scale) {
            shot
            VStack(alignment: .leading, spacing: 4 * scale) {
                HStack(spacing: R.spacingSpace4) {
                    Text(product.name)
                        .backstageText(nameStyle)
                        .foregroundStyle(M.textPrimary)
                        .lineLimit(1)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    if !product.dots.isEmpty { colourDots }
                }
                if showsBrand {
                    Text(product.brand)
                        .backstageText(.label3)
                        .foregroundStyle(P.white50)
                }
            }
            DropPrice(price: product.price, mrp: product.mrp,
                      priceStyle: scale < 1 ? .label3 : .title4, mrpSize: scale < 1 ? 10 : 12)
        }
        .padding(.horizontal, 8 * scale)
        .padding(.top, 8 * scale)
        .padding(.bottom, 12 * scale)
        .frame(width: imageWidth + 16 * scale, alignment: .leading)
        .background {
            // Overlays, not a ZStack: the 385pt glow must not size the background, or the card's
            // tappable area spills ~80pt past its edges onto the neighbouring card.
            M.surfaceTransparent
                .overlay(alignment: .top) {
                    Image(product.backdrop)
                        .resizable()
                        .scaledToFill()
                        .frame(width: imageWidth, height: imageHeight)
                        .blur(radius: 40 * scale)
                        .opacity(0.5)
                        .padding(.top, 8 * scale)
                }
                .overlay(alignment: .top) {
                    Image("pd_card_glow")
                        .resizable()
                        .frame(width: 385 * scale, height: 147 * scale)
                        .offset(y: -90 * scale)
                }
                .allowsHitTesting(false)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
        // Clipping hides overflow but doesn't stop it catching taps; pin hits to the card itself.
        .contentShape(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24 * scale, style: .continuous).strokeBorder(P.cardEdge, lineWidth: scale < 1 ? 0.74 : 1))
        .shadow(color: .black.opacity(0.1), radius: 4, y: 4)
        .shadow(color: .black.opacity(0.09), radius: 8, y: 15)
        .accessibilityElement(children: .combine)
    }

    private var shot: some View {
        ZStack {
            Color.white.opacity(0.2)
            if product.photoCard {
                Image(product.image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: imageWidth, height: imageHeight)
            } else {
                Image(product.image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: imageWidth * 0.6873)
            }
        }
        .frame(width: imageWidth, height: imageHeight)
        .clipShape(RoundedRectangle(cornerRadius: 16 * scale, style: .continuous))
        .overlay(alignment: .topLeading) {
            Text(product.tag)
                .dropFont("Medium", 10)
                .foregroundStyle(product.tag == "Unisex" ? P.white70 : M.textPrimary)
                .padding(.horizontal, 6)
                .padding(.vertical, 1)
                .background(Color.black.opacity(product.tag == "Unisex" ? 0.08 : 0.48), in: Capsule())
                .padding(8 * scale)
        }
        .overlay(alignment: .topTrailing) {
            if let logo = product.brandLogo {
                Image(logo)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 23, height: 15)
                    .frame(width: 24, height: 24)
                    .background(Color.white, in: Circle())
                    .padding(5 * scale)
                    .accessibilityHidden(true)
            }
        }
    }

    private var colourDots: some View {
        HStack(spacing: 2) {
            ForEach(product.dots, id: \.self) { Image($0).resizable().frame(width: 10, height: 10) }
            if product.moreColours > 0 && scale < 1 {
                Text("\(product.moreColours)")
                    .dropFont("Medium", 10)
                    .foregroundStyle(M.textPrimary)
            }
        }
        .padding(.leading, 4)
        .padding(.trailing, 6)
        .frame(height: 18)
        .background(Color.black.opacity(0.32), in: Capsule())
        .accessibilityLabel("More colours")
    }
}

// MARK: - Landing

/// "Drops landing page" (Figma 7663:11885).
struct DropsLandingView: View {
    @Environment(DropFlow.self) private var flow
    var close: () -> Void
    @State private var gender = "All"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                masthead
                    .padding(.bottom, 28)
                VStack(alignment: .leading, spacing: R.spacingSpace42) {
                    topDeals
                    sneakers
                    hotThisWeek
                }
                .padding(.horizontal, R.spacingSpace16)
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .background(alignment: .top) {
            Image("pd_texture")
                .resizable()
                .frame(width: 457, height: 457)
                .rotationEffect(.degrees(90))
                .opacity(0.03)
                .offset(x: -114, y: -92)
                .accessibilityHidden(true)
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack {
                GlassIconButton(systemName: "arrow.left", label: "Close drops", action: close)
                Spacer()
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.vertical, R.spacingSpace4)
            .background(LinearGradient(colors: [Color(rgba: 0x0C0B0EB3), .clear], startPoint: .top, endPoint: .bottom).ignoresSafeArea())
        }
    }

    private var masthead: some View {
        VStack(spacing: R.spacingSpace12) {
            Text("Lock in the")
                .dropFont("Medium", 12)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(Color(rgba: 0xF3F3F2FF))
            CrazyDropsTitle()
            steps.padding(.top, R.spacingSpace16)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, R.spacingSpace8)
    }

    private var steps: some View {
        HStack(alignment: .top, spacing: 0) {
            step(icon: "pd_step_discover", title: "Discover the Drop")
            rail
            step(icon: "pd_step_reserve", inner: "pd_step_reserve_inner", title: "Reserve Your Pick")
            rail
            step(icon: "pd_step_collect", title: "Go Out & Collect")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Discover the drop, reserve your pick, go out and collect")
    }

    private func step(icon: String, inner: String? = nil, title: String) -> some View {
        VStack(spacing: R.spacingSpace8) {
            ZStack {
                Image(icon).resizable().frame(width: 24, height: 24)
                if let inner { Image(inner).resizable().frame(width: 16, height: 16) }
            }
            Text(title)
                .backstageText(.label3)
                .foregroundStyle(P.white70)
                .multilineTextAlignment(.center)
        }
        .frame(width: 76)
    }

    private var rail: some View {
        LinearGradient(colors: [M.backgroundSecondary, P.railEnd], startPoint: .leading, endPoint: .trailing)
            .frame(width: 34, height: 2)
            .clipShape(Capsule())
            .padding(.top, 11)
            .padding(.horizontal, 4)
    }

    // MARK: Sections

    private var topDeals: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace4) {
                // Both SVGs carry their glow as padding; Figma insets them -220%/-105% and -33%/-12%.
                ZStack {
                    Image("pd_bolt").resizable().frame(width: 62.1, height: 71.4)
                    Image("pd_bolt_glow").resizable().frame(width: 19, height: 28.3).blendMode(.plusLighter)
                }
                .frame(width: 11.5, height: 23)
                .accessibilityHidden(true)
                DropSectionTitle(text: "Top deals", texture: "pd_tex_topdeals")
            }
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace16) {
                    ForEach(DropsData.topDeals) { p in productLink(p) }
                }
                .padding(.top, R.spacingSpace8)
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private var sneakers: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(alignment: .bottom) {
                DropSectionTitle(text: "Sneakers", texture: "pd_tex_sneakers")
                Spacer()
                Button { flow.path.append(.listing) } label: {
                    HStack(spacing: 2) {
                        Text("See all")
                        Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
                    }
                    .font(.custom("BeVietnamPro-SemiBold", size: 14, relativeTo: .subheadline))
                    .foregroundStyle(Color(rgba: 0xD8D8D8FF))
                    .frame(minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .frame(height: 24)
            HStack(spacing: R.spacingSpace8) {
                ForEach(["All", "Men", "Women"], id: \.self) { g in
                    DropChip(title: g, selected: gender == g) { gender = g }
                }
            }
            .padding(.vertical, -6)
            ScrollView(.horizontal) {
                HStack(spacing: 14) {
                    ForEach(DropsData.sneakers) { p in productLink(p, showsBrand: false) }
                }
                .padding(.top, R.spacingSpace12)
                .scrollTargetLayout()
            }
            .scrollClipDisabled()
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    private func productLink(_ p: DropProduct, showsBrand: Bool = true) -> some View {
        Button { flow.path.append(.product(p)) } label: {
            DropProductCard(product: p, showsBrand: showsBrand)
        }
        .buttonStyle(PressableStyle())
    }

    private var hotThisWeek: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack(spacing: R.spacingSpace4) {
                Image("pd_fire").resizable().frame(width: 23, height: 23).accessibilityHidden(true)
                DropSectionTitle(text: "Hot this week", texture: "pd_tex_hot")
            }
            Button { flow.path.append(.product(DropsData.speedcat)) } label: { HotDeck() }
                .buttonStyle(PressableStyle())
        }
    }
}

/// Section titles: 22 Bold, white with the Figma's grain texture and a soft drop shadow.
struct DropSectionTitle: View {
    let text: String
    let texture: String

    var body: some View {
        Text(text)
            .dropFont("Bold", 22, relativeTo: .title2)
            .tracking(-0.66)
            .foregroundStyle(.white)
            .overlay {
                Image(texture)
                    .resizable()
                    .blendMode(.multiply)
                    .mask { Text(text).dropFont("Bold", 22, relativeTo: .title2).tracking(-0.66) }
            }
            .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
            .shadow(color: .black.opacity(0.09), radius: 2, y: 3)
            .accessibilityAddTraits(.isHeader)
    }
}

/// "Hot this week": the lead card with two cards fanned behind it.
private struct HotDeck: View {
    var body: some View {
        ZStack(alignment: .leading) {
            backCard("pd_hot_back", width: 238, height: 358.8, radius: 28.4).opacity(0.05).offset(x: 90)
            Image("pd_hot_hoodie")
                .resizable()
                .scaledToFill()
                .frame(width: 258, height: 389)
                .overlay(alignment: .bottom) {
                    caption(brand: "Almost gods", name: "Alpha Cross Hoodie", text: "Elevated streetwear with a bold Almost Gods edge.",
                            price: 9_999, mrp: 10_999, scale: 0.963)
                        .padding(7.7)
                }
                .clipShape(RoundedRectangle(cornerRadius: 30.8, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 30.8, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.963))
                .opacity(0.6)
                .offset(x: 35)
            backCard("pd_hot_back", width: 248, height: 373.9, radius: 29.6).opacity(0.1).offset(x: 63)
            Image("pd_hot_speedcats")
                .resizable()
                .scaledToFill()
                .frame(width: 268, height: 404)
                .overlay(alignment: .bottom) {
                    caption(brand: "Puma", name: "Speedcats", text: "Elevated streetwear shoe with a bold Almost Gods edge.",
                            price: 9_999, mrp: 10_999, scale: 1)
                        .padding(R.spacingSpace8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 32, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 32, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: .black.opacity(0.1), radius: 5, y: 4)
                .shadow(color: .black.opacity(0.09), radius: 8, y: 17)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(height: 404)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hot this week: Puma Speedcats, \(rupees(9_999))")
        .accessibilityAddTraits(.isButton)
    }

    private func backCard(_ image: String, width: CGFloat, height: CGFloat, radius: CGFloat) -> some View {
        Image(image)
            .resizable()
            .scaledToFill()
            .frame(width: width, height: height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).strokeBorder(Color.white.opacity(0.16), lineWidth: 0.9))
    }

    private func caption(brand: String, name: String, text: String, price: Int, mrp: Int, scale: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: R.spacingSpace8) {
                Image("pd_brand_avatar")
                    .resizable()
                    .frame(width: 24 * scale, height: 24 * scale)
                    .clipShape(Circle())
                Text(brand)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
            }
            .padding(.top, 17.6 * scale)
            Rectangle().fill(Color.white.opacity(0.12)).frame(height: 1).padding(.vertical, 10 * scale)
            Text(name)
                .backstageText(.title4)
                .foregroundStyle(M.textWhite)
            Text(text)
                .backstageText(.body3)
                .foregroundStyle(P.white50)
                .lineLimit(2)
                .padding(.top, 2)
            DropPrice(price: price, mrp: mrp, mrpSize: 11)
                .padding(.top, R.spacingSpace8)
                .padding(.bottom, R.spacingSpace12)
        }
        .padding(.horizontal, 9.6 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.ultraThinMaterial.opacity(0.35), in: RoundedRectangle(cornerRadius: 27 * scale, style: .continuous))
        .background(Color(rgba: 0x13131380), in: RoundedRectangle(cornerRadius: 27 * scale, style: .continuous))
    }
}

// MARK: - Listing

/// "Category landing (generic)" (Figma 7663:12106): the Sneakers grid.
struct DropsListingView: View {
    @Environment(DropFlow.self) private var flow
    @State private var gender: String? = "Men"
    private let columns = [GridItem(.flexible(), spacing: 10.4), GridItem(.flexible(), spacing: 10.4)]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: columns, spacing: 10.4) {
                ForEach(DropsData.listing) { p in
                    Button { flow.path.append(.product(p)) } label: {
                        DropProductCard(product: p, scale: 0.74, nameStyle: .label2, width: 165)
                    }
                    .buttonStyle(PressableStyle())
                }
            }
            .padding(.horizontal, R.spacingSpace16)
            .padding(.top, R.spacingSpace8)
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            VStack(spacing: 0) {
                DropPageHeader(title: "Sneakers") {
                    Button {} label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(M.iconPrimary)
                            .frame(width: 44, height: 44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Search sneakers")
                }
                filters
            }
            .background(M.backgroundPrimary)
        }
    }

    private var filters: some View {
        ScrollView(.horizontal) {
            HStack(spacing: R.spacingSpace8) {
                Button {} label: {
                    HStack(spacing: R.spacingSpace8) {
                        Image(systemName: "slider.horizontal.3").font(.system(size: 12, weight: .medium))
                        Text("Filters")
                        Image(systemName: "chevron.down").font(.system(size: 10, weight: .semibold))
                    }
                    .backstageText(.label2)
                    .foregroundStyle(M.textPrimary)
                    .padding(.horizontal, R.spacingSpace12)
                    .frame(height: 32)
                    .background(M.backgroundSecondary, in: Capsule())
                    .overlay(Capsule().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .frame(minHeight: 44)
                }
                .buttonStyle(.plain)
                ForEach(["Men", "Women", "Kids"], id: \.self) { g in
                    DropChip(title: g, selected: gender == g, removable: true) { gender = gender == g ? nil : g }
                }
            }
            .padding(.horizontal, R.spacingSpace16)
        }
        .scrollIndicators(.hidden)
    }
}

// MARK: - PDP

/// PDP type scale: one family (Be Vietnam Pro), sentence case throughout.
private enum PDPType {
    /// Product name.
    static func name(_ t: Text) -> some View { t.dropFont("SemiBold", 22, relativeTo: .title2).tracking(-0.22) }
    /// Headline price.
    static func price(_ t: Text) -> some View { t.dropFont("SemiBold", 20, relativeTo: .title3) }
}

/// Drop product page, restyled after the editorial `ProductDetailView`: a wash drawn from the photo
/// on screen, inset photo cards with a thumbnail strip for every SKU photo, the best price with
/// coupon and bank offer, sizes with a guide, hairline details and a bottom dock. Reserve-only drops
/// carry an info band on the dock that opens the explainer; pay-in-full drops add to cart.
struct DropsProductView: View {
    @Environment(DropFlow.self) private var flow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let product: DropProduct
    @State private var colour: DropColour
    @State private var size: String?
    @State private var readMore = false
    @State private var bestPriceSheet = ProcessInfo.processInfo.arguments.contains("-dropsBestPrice")
    @State private var shot: Int? = 0
    @State private var pickup: Bool = {
        #if DEBUG
        return ProcessInfo.processInfo.arguments.contains("-dropsSheet")
        #else
        return false
        #endif
    }()
    @State private var info: DropCartSheet? = {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-dropsPDPInfo") { return .reserve }
        #endif
        return nil
    }()
    @State private var sizeGuide = ProcessInfo.processInfo.arguments.contains("-dropsSizeGuide")
    @State private var nudge = 0
    @State private var sizesVisible = true

    init(product: DropProduct) {
        self.product = product
        _colour = State(initialValue: product.colourways[0])
    }

    private var reserves: Bool { product.payment == .reserve }
    private var reserveNow: Int { Int((Double(product.price) * 0.25).rounded()) }
    private var hasColours: Bool { !product.colours.isEmpty }
    private var shots: [String] { colour.images }
    private var currentShot: String { shots[min(shot ?? 0, shots.count - 1)] }
    /// Cutouts sit on a tinted tile; photographs fill the card.
    private func isCutout(_ name: String) -> Bool { DropShotImage.base(name) == product.image && !hasColours }

    @State private var titleShown = false

    var body: some View {
        ScrollViewReader { proxy in
            GeometryReader { screen in
                ZStack(alignment: .top) {
                    backdrop
                    ScrollView {
                        VStack(alignment: .leading, spacing: R.spacingSpace24) {
                            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                                intro
                                gallery
                                pricing
                            }
                            if hasColours { colours }
                            sizes(screenHeight: screen.size.height + screen.safeAreaInsets.bottom)
                            highlights
                            descriptionSection
                            pickupSection
                            DropLinkList(rows: [("questionmark.circle", "Frequently asked questions"), ("doc.text", "Terms and conditions")])
                        }
                        .padding(.horizontal, R.spacingSpace16)
                        .padding(.top, screen.safeAreaInsets.top + 64)
                        .padding(.bottom, 150)
                    }
                    .scrollIndicators(.hidden)
                    .ignoresSafeArea(edges: .top)
                    controls
                }
                .overlay(alignment: .bottom) { actionBar(proxy) }
            }
            #if DEBUG
            // `-dropsTapCTA` taps the CTA a second after opening, to check the scroll-to-size nudge.
            .task {
                if ProcessInfo.processInfo.arguments.contains("-dropsScrollBest") {
                    try? await Task.sleep(for: .seconds(0.6))
                    proxy.scrollTo("sizes", anchor: .center)
                }
                guard ProcessInfo.processInfo.arguments.contains("-dropsTapCTA") else { return }
                try? await Task.sleep(for: .seconds(1))
                askForSize(proxy)
            }
            #endif
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .sheet(isPresented: $pickup) { DropsPickupSheet(onProceed: proceed) }
        .sheet(isPresented: $sizeGuide) { DropSizeGuideSheet(selected: $size) }
        .sheet(isPresented: $bestPriceSheet) {
            DropBestPriceSheet(product: product) {
                bestPriceSheet = false
                flow.path.append(.offers)
            }
        }
        .sheet(item: $info) { s in
            switch s {
            case .nonRefundable: DropNonRefundableSheet(reserveAmount: reserveNow)
            default: DropReserveSheet(preview: product) { info = .nonRefundable }
            }
        }
        .sensoryFeedback(.selection, trigger: size)
        .sensoryFeedback(.warning, trigger: nudge)
    }

    private func proceed() {
        let label = hasColours ? colour.name : product.tag
        // A cart holds one payment type, so starting a different kind of drop starts a fresh cart.
        if flow.plan != product.payment { flow.cart.removeAll() }
        flow.plan = product.payment
        flow.balancePaid = false
        if let i = flow.cart.firstIndex(where: { $0.product == product && $0.colour == label && $0.size == size }) {
            flow.cart[i].quantity = min(flow.cart[i].quantity + 1, 4)
        } else {
            flow.cart.append(DropCartItem(product: product, colour: label, size: size ?? "", image: colour.swatch))
        }
        pickup = false
        flow.path.append(.cart)
    }

    /// No size yet: bring the size row into view if it isn't, then shake it.
    private func askForSize(_ proxy: ScrollViewProxy) {
        if sizesVisible {
            nudge += 1
        } else {
            withAnimation(reduceMotion ? nil : .smooth(duration: 0.45)) { proxy.scrollTo("sizes", anchor: .center) }
            DispatchQueue.main.asyncAfter(deadline: .now() + (reduceMotion ? 0.05 : 0.5)) { nudge += 1 }
        }
    }

    // MARK: Backdrop & chrome

    /// Figma "Hub-page": plain background/primary with one big, soft white glow behind the top.
    private var backdrop: some View {
        // In an overlay so its 541pt width never widens the screen's layout.
        Color.clear
            .overlay(alignment: .top) {
                Ellipse()
                    .fill(Color(rgba: 0xEFEFEFFF).opacity(0.16))
                    .frame(width: 541, height: 507)
                    .blur(radius: 75)
                    .offset(y: 70)
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var controls: some View {
        GlassGroup(spacing: R.spacingSpace8) {
            HStack(spacing: R.spacingSpace12) {
                GlassIconButton(systemName: "arrow.left", label: "Back") { dismiss() }
                // The hot flame travels with the name into the header, so the status stays visible.
                HStack(spacing: 6) {
                    Image("pd_fire").resizable().frame(width: 16, height: 16).accessibilityHidden(true)
                    Text(product.name)
                }
                    .backstageText(.title2)
                    .tracking(-0.18)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                    .opacity(titleShown ? 1 : 0)
                    .offset(y: titleShown ? 0 : 6)
                    .accessibilityHidden(!titleShown)
                Spacer(minLength: 0)
                ShareLink(item: "\(product.name) on District drops") {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(M.iconPrimary)
                        .frame(width: 44, height: 44)
                        .liquidGlass(in: Circle(), interactive: true, clear: true)
                }
                .accessibilityLabel("Share \(product.name)")
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, R.spacingSpace4)
        .padding(.bottom, R.spacingSpace12)
        .background {
            // Figma header: a dark fade over a light blur.
            LinearGradient(colors: [Color(rgba: 0x0C0B0E80), Color(rgba: 0x0C0B0E00)], startPoint: .top, endPoint: .bottom)
                .background(M.backgroundPrimary.opacity(titleShown ? 0.92 : 0))
                .background(.ultraThinMaterial.opacity(titleShown ? 1 : 0))
                .mask(LinearGradient(colors: [.black, .black, .clear], startPoint: .top, endPoint: .bottom))
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }

    // MARK: Intro

    /// The Figma's caps label: Label 2 face, uppercase, 1.2 tracking.
    private func capsLabel(_ text: String) -> some View {
        Text(text)
            .dropFont("Medium", 12, relativeTo: .subheadline)
            .tracking(1.2)
            .textCase(.uppercase)
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                // Status sits with the product's identity, as an eyebrow above brand and name.
                HotNowTag()
                    .padding(.bottom, R.spacingSpace4)
                HStack(spacing: R.spacingSpace8) {
                    capsLabel(product.brand)
                    Circle().fill(M.textTertiary).frame(width: 5, height: 5)
                    capsLabel(product.tag)
                }
                .foregroundStyle(M.textSecondary)
                .accessibilityElement(children: .combine)
                Text(product.name)
                    .backstageText(.title2)
                    .tracking(-0.18)
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                    // The name moves into the header once it scrolls under it.
                    .onGeometryChange(for: Bool.self) { $0.frame(in: .global).maxY < 110 } action: { shown in
                        withAnimation(.easeOut(duration: 0.2)) { titleShown = shown }
                    }
            }
            Text(product.tagline ?? "Check out \(product.brand)'s \(product.name) — stylish, comfy, and part of this week's drop. Limited pairs, picked up in store.")
                .backstageText(.body3)
                .foregroundStyle(M.textTertiary)
                .opacity(0.9)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Gallery

    /// Square photos (Figma 222pt) in a row that bleeds off the right edge.
    private var gallery: some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: R.spacingSpace8) {
                ForEach(Array(shots.enumerated()), id: \.offset) { i, name in
                    Button { flow.path.append(.gallery(product, colour: colour.id, index: i)) } label: {
                        photo(name)
                            .frame(width: 222, height: 222)
                            .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                    }
                    .buttonStyle(PressableStyle())
                    .id(i)
                    .accessibilityLabel("Photo \(i + 1) of \(shots.count)")
                    .accessibilityHint("Opens the gallery")
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $shot)
        .scrollIndicators(.hidden)
        // Laid out in the column's width, drawn past it so the next photo peeks in from the edge.
        .scrollClipDisabled()
        .frame(height: 222)
        .id(colour.id)
    }

    @ViewBuilder private func photo(_ name: String) -> some View {
        if isCutout(name) {
            DropShotImage(spec: name, inset: R.spacingSpace40)
                .background(Color.white.opacity(0.06))
        } else {
            DropShotImage(spec: name, fill: true)
        }
    }

    // MARK: Price

    private var pricing: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace4) {
                    Text(rupees(product.price))
                        .backstageText(.title2)
                        .tracking(-0.18)
                        .foregroundStyle(M.textPrimary)
                    Text(rupees(product.mrp))
                        .dropFont("Medium", 12)
                        .strikethrough()
                        .foregroundStyle(M.textSecondary.opacity(0.6))
                        .accessibilityLabel("was \(rupees(product.mrp))")
                }
                Text("\(rupees(product.mrp - product.price)) OFF")
                    .backstageText(.label2)
                    .foregroundStyle(M.textOffer)
                if reserves {
                    // How reserving splits the price; opens the explainer.
                    Button { info = .reserve } label: {
                        HStack(spacing: R.spacingSpace4) {
                            Text("Pay \(rupees(reserveNow)) now, \(rupees(product.price - reserveNow)) at pick-up")
                            Image(systemName: "info.circle").font(.system(size: 11, weight: .medium))
                        }
                        .backstageText(.label2)
                        .foregroundStyle(M.textSecondary)
                        .frame(minHeight: 28)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Explains how reserving works")
                }
            }
            DropBestPriceRow(product: product) { bestPriceSheet = true }
                .id("best-price")
        }
    }

    // MARK: Choices

    private var colours: some View {
        VStack(alignment: .leading, spacing: 14) {
            (Text("Colour").foregroundStyle(M.textPrimary)
             + Text(" • \(colour.name.replacingOccurrences(of: "-", with: " on "))").foregroundStyle(M.textSecondary))
                .dropFont("Medium", 12, relativeTo: .subheadline)
                .tracking(1.2)
                .textCase(.uppercase)
                .lineLimit(1)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                HStack(spacing: R.spacingSpace12) {
                    ForEach(product.colours) { c in
                        let on = colour == c
                        Button { withAnimation(reduceMotion ? nil : .smooth(duration: 0.4)) { colour = c; shot = 0 } } label: {
                            Image(c.swatch)
                                .resizable()
                                .scaledToFill()
                                .frame(width: 74, height: 74)
                                .clipShape(RoundedRectangle(cornerRadius: 9.8, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 9.8, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: 0.8))
                                .padding(3)
                                .overlay(RoundedRectangle(cornerRadius: 13, style: .continuous)
                                    .strokeBorder(on ? M.borderSelection : .clear, lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(c.name), \(c.images.count) photos")
                        .accessibilityAddTraits(on ? .isSelected : [])
                    }
                }
            }
            .scrollIndicators(.hidden)
        }
    }

    private func sizes(screenHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            HStack {
                capsLabel(size.map { "Choose size • UK \($0)" } ?? "Choose size • UK")
                    .foregroundStyle(M.textPrimary)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button { sizeGuide = true } label: {
                    Label("Size guide", systemImage: "ruler")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(BackstageTextButtonStyle())
            }
            LazyVGrid(columns: Array(repeating: GridItem(.fixed(60), spacing: R.spacingSpace8), count: 5),
                      alignment: .leading, spacing: R.spacingSpace8) {
                ForEach(product.sizeRun ?? DropsData.sizes, id: \.self) { s in
                    let on = s == size
                    Button { withAnimation(.snappy) { size = s } } label: {
                        Text(s)
                            .dropFont("Medium", 14)
                            .foregroundStyle(on ? M.textPrimary : M.textSecondary)
                            .frame(width: 60, height: 44)
                            .background(on ? M.surfaceTransparent : M.buttonFilterBackground,
                                        in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous))
                            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                                .strokeBorder(on ? M.borderSelection : M.borderIntense, lineWidth: R.stroke1Px))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("UK size \(s)")
                    .accessibilityAddTraits(on ? .isSelected : [])
                }
            }
            .modifier(Shake(trigger: nudge))
            if nudge > 0 && size == nil {
                Label("Pick a size to continue", systemImage: "exclamationmark.circle")
                    .backstageText(.label3)
                    .foregroundStyle(P.warning)
                    .transition(.opacity)
            }
        }
        .id("sizes")
        // Visible means clear of the header and of the floating bar.
        .onGeometryChange(for: Bool.self) { g in
            let f = g.frame(in: .global)
            return f.minY > 100 && f.maxY < screenHeight - 130
        } action: { sizesVisible = $0 }
    }

    /// Figma highlights: four small tiles, the label on a tinted cap above the value.
    private var highlights: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            capsLabel("Highlights").foregroundStyle(M.textPrimary).accessibilityAddTraits(.isHeader)
            HStack(spacing: R.spacingSpace8) {
                ForEach(DropsData.highlights, id: \.0) { h in
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
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity)
                            .padding(R.spacingSpace4)
                    }
                    .frame(width: 68)
                    .background(M.surfaceTransparent)
                    .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 1, y: 1)
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }

    /// The description with an inline "Read more" that unfolds the full specs.
    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            capsLabel("Description").foregroundStyle(M.textPrimary).accessibilityAddTraits(.isHeader)
            let body = product.about ?? (hasColours ? DropsData.description : nil) ?? "The \(product.name) from \(product.brand), part of this week's drop. Limited pairs, picked up in store."
            Button { withAnimation(.snappy) { readMore.toggle() } } label: {
                (Text(body + " ").foregroundStyle(M.textTertiary)
                 + Text(readMore ? "Read less" : "Read more").foregroundStyle(Color.white.opacity(0.9)))
                    .backstageText(.body3)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .buttonStyle(.plain)
            .accessibilityHint(readMore ? "Hides the specifications" : "Shows the specifications")
            if readMore {
                VStack(spacing: 0) {
                    ForEach(DropsData.specs, id: \.0) { r in
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
                .transition(.opacity)
            }
        }
    }

    private var pickupSection: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace12) {
            capsLabel("Pick up").foregroundStyle(M.textPrimary).accessibilityAddTraits(.isHeader)
            HStack(alignment: .top, spacing: R.spacingSpace12) {
                Image(systemName: "storefront")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 36, height: 36)
                    .background(M.surfaceTransparent, in: Circle())
                    .accessibilityHidden(true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("At \(DropsData.stores.count) stores near you").backstageText(.title4).foregroundStyle(M.textPrimary)
                    Text("Nearest \(DropsData.stores[0].distance) • choose your store and slot next")
                        .backstageText(.body3)
                        .foregroundStyle(M.textTertiary)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
        }
    }

    // MARK: Action bar

    /// Figma "Action Card Glass": one CTA in a frosted capsule, with the always-on "Hot right now"
    /// sticker riding its top edge so it stays in view on every scroll position.
    private func actionBar(_ proxy: ScrollViewProxy) -> some View {
        Button {
            if size == nil { askForSize(proxy) } else { pickup = true }
        } label: {
            Text(reserves ? "Pay 25% to reserve" : "Add to cart").frame(maxWidth: .infinity)
        }
        .buttonStyle(BackstagePrimaryButtonStyle())
        .accessibilityHint(size == nil ? "Choose a size first" : "")
        .padding(R.spacingSpace16)
        .background(Color.black.opacity(0.56), in: Capsule())
        .background(.ultraThinMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.08), lineWidth: R.stroke1Px))
        .padding(.horizontal, R.spacingSpace16)
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
}

/// The drop's "Hot right now" status, shown as an eyebrow above the brand and name (like Nike's
/// "Just In" / "Bestseller"): a small warm-tinted pill with a flickering flame. It's a status, not
/// an action, so it has no chevron, glass or press state. The flame also leads the header title
/// once the name scrolls up, so the status never leaves the screen.
struct HotNowTag: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private static let heat = LinearGradient(colors: [Color(rgba: 0xFFB36BFF), Color(rgba: 0xFF6A5FFF)], startPoint: .leading, endPoint: .trailing)

    var body: some View {
        HStack(spacing: R.spacingSpace4) {
            Image("pd_fire")
                .resizable()
                .frame(width: 14, height: 14)
                .phaseAnimator(reduceMotion ? [false] : [false, true]) { flame, up in
                    flame.scaleEffect(up ? 1.15 : 0.95, anchor: .bottom).rotationEffect(.degrees(up ? 4 : -4), anchor: .bottom)
                } animation: { _ in .easeInOut(duration: 0.6) }
            Text("Hot right now")
                .dropFont("SemiBold", 12, relativeTo: .caption)
                .foregroundStyle(Self.heat)
        }
        .padding(.leading, 6)
        .padding(.trailing, R.spacingSpace8)
        .frame(height: 24)
        .background(Color(rgba: 0xFF6A3DFF).opacity(0.14), in: Capsule())
        .overlay(Capsule().strokeBorder(Color(rgba: 0xFF8A5BFF).opacity(0.3), lineWidth: R.stroke1Px))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Hot right now")
    }
}

/// "Get it at" as a coupon ticket. The top stub holds the best price against today's price, with
/// a tilted savings stamp. A perforated tear line with notched edges divides it from the foot,
/// where each offer shows what it takes off. Offer purple, not green. The breakdown opens in
/// `DropBestPriceSheet`.
struct DropBestPriceRow: View {
    let product: DropProduct
    let action: () -> Void

    /// Height of the top stub; the tear line and its notches sit here.
    private static let stub: CGFloat = 92
    private static let shape = TicketShape(notchY: stub, notchRadius: 9, cornerRadius: 18)

    var body: some View {
        let best = product.bestPrice
        Button(action: action) {
            VStack(spacing: 0) {
                top(best)
                    .frame(height: Self.stub)
                Perforation()
                    .stroke(M.textOffer.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [5, 4]))
                    .frame(height: 1)
                    .padding(.horizontal, 14)
                foot(best)
            }
            .background {
                LinearGradient(colors: [Color(rgba: 0x2A1C6BFF), M.brandPurple900, M.surfaceSecondary],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                    .overlay(alignment: .topTrailing) {
                        // A soft violet light behind the stamp.
                        Circle().fill(M.surfaceOfferPrimary.opacity(0.45)).frame(width: 160).blur(radius: 50).offset(x: 30, y: -50)
                    }
            }
            .clipShape(Self.shape)
            .overlay(Self.shape.stroke(LinearGradient(colors: [M.textOffer.opacity(0.55), M.textOffer.opacity(0.08)],
                                                      startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1))
            .contentShape(Self.shape)
        }
        .buttonStyle(PressableStyle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Get it at \(rupees(best.final)), you save \(rupees(best.coupon + best.bank)) with coupon FIRST10 and HSBC card offer")
        .accessibilityHint("Shows how the price is worked out")
        .accessibilityAddTraits(.isButton)
    }

    private func top(_ best: (coupon: Int, bank: Int, final: Int)) -> some View {
        HStack(alignment: .center, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("Get it at")
                    .dropFont("Medium", 11, relativeTo: .caption)
                    .tracking(1.1)
                    .textCase(.uppercase)
                    .foregroundStyle(M.textOffer)
                HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
                    Text(rupees(best.final))
                        .dropFont("Bold", 26, relativeTo: .title)
                        .tracking(-0.4)
                        .foregroundStyle(M.textPrimary)
                    Text(rupees(product.price))
                        .dropFont("Medium", 13)
                        .strikethrough()
                        .foregroundStyle(M.textSecondary.opacity(0.6))
                }
                Text("with coupon + bank offer")
                    .backstageText(.label3)
                    .foregroundStyle(M.textSecondary)
            }
            Spacer(minLength: 0)
            SavingsStamp(amount: best.coupon + best.bank)
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    private func foot(_ best: (coupon: Int, bank: Int, final: Int)) -> some View {
        HStack(spacing: R.spacingSpace8) {
            offerChip(label: "FIRST10", saving: best.coupon) {
                Image("pd_offer_badge").resizable().scaledToFit().frame(width: 18, height: 18)
            }
            offerChip(label: "HSBC", saving: best.bank) {
                Image("pd_bank_hsbc").resizable().scaledToFill().frame(width: 16, height: 16).clipShape(Circle())
            }
            Spacer(minLength: 0)
            HStack(spacing: 2) {
                Text("Details")
                Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold))
            }
            .backstageText(.button3)
            .foregroundStyle(M.textPrimary)
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, R.spacingSpace12)
    }

    private func offerChip<Icon: View>(label: String, saving: Int, @ViewBuilder icon: () -> Icon) -> some View {
        HStack(spacing: 6) {
            icon()
            Text(label)
                .dropFont("SemiBold", 11, relativeTo: .caption)
                .tracking(0.4)
                .foregroundStyle(M.textPrimary)
            Text("−\(rupees(saving))")
                .dropFont("SemiBold", 11, relativeTo: .caption)
                .foregroundStyle(M.textOffer)
        }
        .padding(.leading, 6)
        .padding(.trailing, R.spacingSpace8)
        .frame(height: 28)
        .background(Color.white.opacity(0.06), in: Capsule())
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.1), lineWidth: R.stroke1Px))
    }
}

/// The tilted "you save" stamp on the ticket: offer purple, a dashed inner rule like a printed
/// stamp, and one slow shine across it when it appears.
private struct SavingsStamp: View {
    let amount: Int
    @State private var shine = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 0) {
            Text("You save")
                .dropFont("SemiBold", 9, relativeTo: .caption2)
                .tracking(1)
                .textCase(.uppercase)
                .foregroundStyle(Color.white.opacity(0.8))
            Text("−\(rupees(amount))")
                .dropFont("Bold", 18, relativeTo: .headline)
                .tracking(-0.2)
                .foregroundStyle(Color.white)
                .fixedSize()
        }
        .padding(.horizontal, R.spacingSpace12)
        .padding(.vertical, R.spacingSpace8)
        .background(
            LinearGradient(colors: [Color(rgba: 0x7B5CFFFF), M.surfaceOfferPrimary], startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .strokeBorder(Color.white.opacity(0.35), style: StrokeStyle(lineWidth: 1, dash: [3, 2.5]))
                .padding(3)
        )
        .overlay {
            // One diagonal shine.
            LinearGradient(colors: [.clear, .white.opacity(0.45), .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: 36)
                .rotationEffect(.degrees(20))
                .offset(x: shine ? 90 : -90)
                .blendMode(.plusLighter)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: M.surfaceOfferPrimary.opacity(0.55), radius: 12, y: 4)
        .rotationEffect(.degrees(-6))
        .task {
            guard !reduceMotion else { return }
            try? await Task.sleep(for: .seconds(0.6))
            withAnimation(.easeInOut(duration: 1.1)) { shine = true }
        }
    }
}

/// A rounded ticket with a semicircle bitten out of each side at `notchY`.
struct TicketShape: Shape {
    let notchY: CGFloat
    var notchRadius: CGFloat = 9
    var cornerRadius: CGFloat = 18

    func path(in rect: CGRect) -> Path {
        var p = Path(roundedRect: rect, cornerRadius: cornerRadius, style: .continuous)
        p = p.subtracting(Path(ellipseIn: CGRect(x: rect.minX - notchRadius, y: rect.minY + notchY - notchRadius,
                                                  width: notchRadius * 2, height: notchRadius * 2)))
        p = p.subtracting(Path(ellipseIn: CGRect(x: rect.maxX - notchRadius, y: rect.minY + notchY - notchRadius,
                                                  width: notchRadius * 2, height: notchRadius * 2)))
        return p
    }
}

/// A straight horizontal line through the middle of its frame (the ticket's tear line).
private struct Perforation: Shape {
    func path(in rect: CGRect) -> Path {
        Path { $0.move(to: CGPoint(x: rect.minX, y: rect.midY)); $0.addLine(to: CGPoint(x: rect.maxX, y: rect.midY)) }
    }
}

/// "Get it at" breakdown, set like a bill rather than a promo card: the price, each offer as a
/// line with its mark and saving, a dashed rule, and what you pay. Neutral surfaces; green only on
/// the savings.
struct DropBestPriceSheet: View {
    @Environment(\.dismiss) private var dismiss
    let product: DropProduct
    var allOffers: () -> Void
    @State private var couponCopied = false

    private var reserves: Bool { product.payment == .reserve }

    var body: some View {
        let best = product.bestPrice
        return DropInfoSheet(title: "Get it at \(rupees(best.final))",
                             subtitle: "Apply a coupon and pay with an offer card at checkout.") {
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                VStack(spacing: 0) {
                    billRow("Price", rupees(product.price))
                    offerRow(mark: AnyView(couponMark), title: "Coupon", code: "FIRST10",
                             detail: "10% off your first drop", saving: best.coupon) {
                        Button(couponCopied ? "Copied" : "Copy code") {
                            UIPasteboard.general.string = "FIRST10"
                            couponCopied = true
                        }
                        .backstageText(.button3)
                        .foregroundStyle(M.textPrimary)
                        .buttonStyle(.plain)
                        .frame(minHeight: 32)
                        .accessibilityLabel(couponCopied ? "Coupon code copied" : "Copy coupon code FIRST10")
                    }
                    offerRow(mark: AnyView(bankLogo("pd_bank_hsbc", size: 32)), title: "HSBC credit card", code: nil,
                             detail: "15% off up to ₹800 on ₹2,000+", saving: best.bank) { EmptyView() }
                    dashedRule.padding(.vertical, R.spacingSpace12)
                    HStack(alignment: .firstTextBaseline) {
                        Text("You pay").backstageText(.title4).foregroundStyle(M.textPrimary)
                        Spacer()
                        Text(rupees(best.final)).backstageText(.title3).foregroundStyle(M.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    Text("You save \(rupees(best.coupon + best.bank)) on top of the drop price")
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, 2)
                }
                .padding(R.spacingSpace16)
                .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))

                Button(action: allOffers) {
                    HStack(spacing: R.spacingSpace12) {
                        HStack(spacing: -8) {
                            ForEach(["pd_bank_hdfc", "pd_bank_idfc", "pd_bank_tide"], id: \.self) { bankLogo($0, size: 24, round: true) }
                        }
                        Text("3 more bank offers").backstageText(.label2).foregroundStyle(M.textPrimary)
                        Spacer()
                        Text("All offers").backstageText(.button3).foregroundStyle(M.textSecondary)
                        Image(systemName: "chevron.right").font(.system(size: 10, weight: .semibold)).foregroundStyle(M.iconSecondary)
                    }
                    .padding(.horizontal, R.spacingSpace16)
                    .frame(minHeight: 52)
                    .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressableStyle())

                if reserves {
                    Text("The bank offer applies to the amount you pay with the card.")
                        .backstageText(.label3)
                        .foregroundStyle(M.textTertiary)
                }
            }
        } actions: {
            Button { dismiss() } label: { Text("Got it").frame(maxWidth: .infinity) }
                .buttonStyle(BackstagePrimaryButtonStyle())
        }
    }

    private var couponMark: some View {
        Image("pd_offer_badge")
            .resizable()
            .scaledToFit()
            .frame(width: 26, height: 26)
            .frame(width: 32, height: 32)
            .background(M.surfaceTransparent, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
            .accessibilityHidden(true)
    }

    private var dashedRule: some View {
        Rectangle()
            .fill(.clear)
            .frame(height: 1)
            .overlay {
                GeometryReader { g in
                    Path { $0.move(to: .zero); $0.addLine(to: CGPoint(x: g.size.width, y: 0)) }
                        .stroke(M.borderModerate, style: StrokeStyle(lineWidth: 1, dash: [4, 4]))
                }
            }
            .accessibilityHidden(true)
    }

    private func billRow(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label).backstageText(.body3).foregroundStyle(M.textSecondary)
            Spacer()
            Text(value).backstageText(.title4).foregroundStyle(M.textPrimary)
        }
        .padding(.bottom, R.spacingSpace12)
        .accessibilityElement(children: .combine)
    }

    private func offerRow<Extra: View>(mark: AnyView, title: String, code: String?, detail: String, saving: Int,
                                       @ViewBuilder extra: () -> Extra) -> some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            mark
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: R.spacingSpace8) {
                    Text(title).backstageText(.title4).foregroundStyle(M.textPrimary)
                    if let code {
                        Text(code)
                            .backstageText(.label3)
                            .tracking(0.6)
                            .foregroundStyle(M.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner4, style: .continuous)
                                .strokeBorder(M.borderIntense, style: StrokeStyle(lineWidth: R.stroke1Px, dash: [3, 2])))
                    }
                }
                Text(detail).backstageText(.label3).foregroundStyle(M.textTertiary)
                extra()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            Text("−\(rupees(saving))").backstageText(.title4).foregroundStyle(P.success)
        }
        .padding(.vertical, R.spacingSpace8)
        .accessibilityElement(children: .combine)
    }

    private func bankLogo(_ name: String, size: CGFloat, round: Bool = false) -> some View {
        Image(name)
            .resizable()
            .scaledToFill()
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: round ? size / 2 : R.cornerRadiusCorner8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: round ? size / 2 : R.cornerRadiusCorner8, style: .continuous)
                .strokeBorder(round ? M.backgroundSecondary : M.borderSubtle, lineWidth: round ? 1.5 : R.stroke1Px))
            .accessibilityHidden(true)
    }
}

/// Size guide: UK to US, EU and foot length; tapping a row picks that size.
struct DropSizeGuideSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String?

    var body: some View {
        DropInfoSheet(title: "Size guide", subtitle: "Speedcats run true to size. Between sizes? Go half up.", symbol: "ruler") {
            VStack(spacing: 0) {
                row(["UK", "US", "EU", "Foot (cm)"], header: true, on: false)
                ForEach(DropsData.sizeChart, id: \.0) { r in
                    Button { selected = r.0; dismiss() } label: {
                        row([r.0, r.1, r.2, r.3], header: false, on: selected == r.0)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("UK \(r.0), US \(r.1), EU \(r.2), \(r.3) centimetres")
                    .accessibilityAddTraits(selected == r.0 ? .isSelected : [])
                }
            }
            .background(DropPalette.card, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            Label("Measure heel to longest toe, standing, at the end of the day.", systemImage: "info.circle")
                .backstageText(.body3)
                .foregroundStyle(M.textSecondary)
        } actions: {
            Button { dismiss() } label: { Text("Done").frame(maxWidth: .infinity) }
                .buttonStyle(BackstagePrimaryButtonStyle())
        }
    }

    private func row(_ cells: [String], header: Bool, on: Bool) -> some View {
        HStack {
            ForEach(Array(cells.enumerated()), id: \.offset) { i, c in
                Text(c)
                    .backstageText(header ? .label3 : (i == 0 ? .title4 : .label2))
                    .foregroundStyle(header ? M.textTertiary : (on ? M.textPrimary : (i == 0 ? M.textPrimary : M.textSecondary)))
                    .frame(maxWidth: .infinity, alignment: i == 0 ? .leading : .trailing)
            }
            if !header {
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 14))
                    .foregroundStyle(on ? DropPalette.success : M.iconQuaternary)
            } else {
                Color.clear.frame(width: 14)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, header ? R.spacingSpace8 : R.spacingSpace12)
        .background(on ? M.surfaceTransparent : .clear)
        .contentShape(Rectangle())
    }
}

/// Horizontal shake to point at a missing choice.
private struct Shake: ViewModifier {
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

/// Bordered list of help rows with leading icons and trailing chevrons.
struct DropLinkList: View {
    let rows: [(String, String)]
    var bordered = true

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                if i > 0 { Rectangle().fill(M.borderSubtle).frame(height: 1) }
                Button {} label: {
                    HStack(spacing: R.spacingSpace16) {
                        Image(systemName: row.0)
                            .font(.system(size: 17))
                            .foregroundStyle(M.iconPrimary)
                            .frame(width: 24, height: 24)
                        Text(row.1)
                            .backstageText(.title4)
                            .foregroundStyle(M.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(M.iconTertiary)
                            .frame(width: 24, height: 24)
                    }
                    .padding(.vertical, R.spacingSpace16)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(bordered ? M.borderSubtle : .clear, lineWidth: R.stroke1Px))
    }
}

// MARK: - Shots

/// One photo of a SKU. A spec is an asset name, optionally with a view suffix for products that
/// only have one cutout so far: `#side` (the other side, mirrored), `#toe` and `#heel` (close-ups).
struct DropShotImage: View {
    let spec: String
    var fill = false
    var inset: CGFloat = 0

    static func base(_ spec: String) -> String { String(spec.split(separator: "#").first ?? Substring(spec)) }
    private var view: String { spec.contains("#") ? String(spec.split(separator: "#").last ?? "") : "" }

    var body: some View {
        let closeUp = view == "toe" || view == "heel"
        Color.clear
            .overlay {
                Group {
                    if fill { Image(Self.base(spec)).resizable().scaledToFill() }
                    else { Image(Self.base(spec)).resizable().scaledToFit() }
                }
                .padding(inset)
                .scaleEffect(x: view == "side" ? -1 : 1, y: 1)
                .scaleEffect(closeUp ? 2.1 : 1, anchor: view == "toe" ? .trailing : (view == "heel" ? .leading : .center))
            }
            .clipped()
            .accessibilityLabel(view == "side" ? "Other side" : (closeUp ? "Close-up" : "Photo"))
    }
}

// MARK: - Gallery

/// Full-screen gallery for any SKU (Figma "Catalogue"): colour chips when there are several
/// colourways, the photo, and a thumbnail strip for every photo of the chosen colourway.
struct DropsGalleryView: View {
    let product: DropProduct
    @State private var colour: DropColour
    @State private var selected: Int

    init(product: DropProduct, colourID: String, index: Int) {
        self.product = product
        let c = product.colourways.first { $0.id == colourID } ?? product.colourways[0]
        _colour = State(initialValue: c)
        _selected = State(initialValue: min(index, c.images.count - 1))
    }

    var body: some View {
        VStack(spacing: 0) {
            if product.colourways.count > 1 {
                ScrollView(.horizontal) {
                    HStack(spacing: R.spacingSpace8) {
                        ForEach(product.colourways) { c in
                            DropChip(title: c.name, selected: colour == c) {
                                withAnimation(.snappy) { colour = c; selected = 0 }
                            }
                        }
                    }
                    .padding(.horizontal, R.spacingSpace16)
                }
                .scrollIndicators(.hidden)
            }
            TabView(selection: $selected) {
                ForEach(Array(colour.images.enumerated()), id: \.offset) { i, name in
                    Color.clear
                        .overlay {
                            DropShotImage(spec: name, inset: product.colours.isEmpty ? R.spacingSpace32 : 0)
                        }
                        .tag(i)
                        .accessibilityLabel("Photo \(i + 1) of \(colour.images.count)")
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .id(colour.id)
            if colour.images.count > 1 {
                HStack(spacing: R.spacingSpace8) {
                    ForEach(Array(colour.images.enumerated()), id: \.offset) { i, name in
                        Button { withAnimation(.easeInOut(duration: 0.2)) { selected = i } } label: {
                            DropShotImage(spec: name, fill: !product.colours.isEmpty, inset: product.colours.isEmpty ? 4 : 0)
                                .background(Color.white.opacity(product.colours.isEmpty ? 0.08 : 0))
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8, style: .continuous))
                                .padding(2)
                                .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner12, style: .continuous)
                                    .strokeBorder(selected == i ? M.borderSelection : .clear, lineWidth: R.stroke1Px))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Photo \(i + 1)")
                        .accessibilityAddTraits(selected == i ? .isSelected : [])
                    }
                }
                .padding(.vertical, R.spacingSpace16)
            } else {
                Spacer().frame(height: R.spacingSpace24)
            }
        }
        .background(M.backgroundPrimary.ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            DropPageHeader(title: product.name,
                           subtitle: product.colours.isEmpty ? product.brand : colour.name.replacingOccurrences(of: "-", with: " / "))
        }
    }
}

#Preview {
    ProductDropsView()
}
