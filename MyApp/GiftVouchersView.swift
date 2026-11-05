import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = DropPalette

// MARK: - Palette

/// Colours from the "Deal of the day" gift voucher Figma (file LysWoZHda2NZfjnOZR1nc2, nodes 3713:7386,
/// 3713:9087, 3713:9396) that have no Mapped token. Used only inside the gift voucher flow.
/// The Figma is green; the deals are rebranded bright blue, so its greens map to the blues below.
/// Text pairs are WCAG-checked against the page (#131316) and cards (#1E1E20); ratios noted inline.
enum VoucherPalette {
    /// Brand accent text: offers, savings, step numbers, ticks. 10.4:1 on the page, 9.4:1 on cards.
    static let accent = Color(rgba: 0x8CC8FFFF)
    /// Fills behind dark text (price tags): ink on it is 11.9:1.
    static let accentFill = Color(rgba: 0xA8D4FFFF)
    /// Saturated blue for rails and decoration only, never text.
    static let accentStrong = Color(rgba: 0x2E7BFFFF)
    static let accentPale = Color(rgba: 0xD6EBFFFF)
    /// Rotates the Figma's green artwork (lockup, bursts, sparkles, glows) onto the blue.
    static let hueShift = Angle.degrees(75)
    /// Price tags (both variants), ink text at 11.9:1.
    static let tag = accentFill
    static let tagBright = accentFill
    /// color/text/warning.
    static let warning = Color(rgba: 0xEBDF6FFF)
    /// Struck "worth" prices: 7.6:1 on the page, 6.8:1 on cards (the Figma's #77777E was 4.2:1).
    static let strike = Color(rgba: 0xA5A5ACFF)
    static let outletPill = Color(rgba: 0x303030FF)
    /// Deep end of the steps rail.
    static let deep = Color(rgba: 0x04204AFF)
    /// "Upto 80% OFF" band.
    static let band = LinearGradient(stops: [.init(color: Color(rgba: 0x001A4DFF), location: 0.17),
                                             .init(color: Color(rgba: 0x0057D9FF), location: 0.53),
                                             .init(color: Color(rgba: 0x0E1E3AFF), location: 0.93)],
                                     startPoint: UnitPoint(x: 0, y: 0.37), endPoint: UnitPoint(x: 1, y: 0.63))
    static let bandText = LinearGradient(colors: [.white, Color(rgba: 0xCCE6FFFF), Color(rgba: 0x94C9FFFF), Color(rgba: 0xBBDDFFFF)],
                                         startPoint: .leading, endPoint: .trailing)
    /// Step labels and the "How it works" kicker.
    /// Solid, not the Figma's gradient, so the darkest letters still clear 7:1 on the hero.
    static let stepText = accentFill
    /// Hero backdrop: the Figma radial, recoloured from green to an electric blue.
    static let heroWash = RadialGradient(stops: [.init(color: Color(rgba: 0x3D7BFFFF), location: 0),
                                                 .init(color: Color(rgba: 0x0A4FC9FF), location: 0.18),
                                                 .init(color: Color(rgba: 0x0066FFFF), location: 0.24),
                                                 .init(color: Color(rgba: 0x0047B3FF), location: 0.43),
                                                 .init(color: Color(rgba: 0x0A3670FF), location: 0.81),
                                                 .init(color: Color(rgba: 0x0E1E3AFF), location: 1)],
                                         center: UnitPoint(x: -0.08, y: 0.31), startRadius: 0, endRadius: 980)
    /// Figma's fade from the page colour into the wash.
    static let heroFade = LinearGradient(stops: [.init(color: P.ink, location: 0),
                                                 .init(color: Color(red: 16 / 255, green: 19 / 255, blue: 28 / 255, opacity: 0.903), location: 0.161),
                                                 .init(color: Color(red: 12 / 255, green: 20 / 255, blue: 38 / 255, opacity: 0.62), location: 0.348),
                                                 .init(color: Color(red: 0, green: 60 / 255, blue: 170 / 255, opacity: 0), location: 1)],
                                         startPoint: .top, endPoint: .bottom)
}

private typealias V = VoucherPalette

extension View {
    /// Moves the Figma's green artwork onto the deals blue.
    func dealTint() -> some View { hueRotation(VoucherPalette.hueShift) }
}

// MARK: - Model

/// How a brand's logo sits in the white panel at the top of a deal card (Figma sizes, 208pt card).
struct VoucherLogo: Hashable {
    let asset: String
    var size: CGSize
    var top: CGFloat
    /// The artwork carries its own colour ground (Giva, CaratLane), so it fills tiles instead of sitting on white.
    var fills = false
    /// Horizontal nudge from centre.
    var dx: CGFloat = 0
}

struct VoucherOutlet: Identifiable, Hashable {
    let name: String
    let km: Double
    var hours = "9:00 AM to 10:30 PM"
    var isOpen = true
    /// An extra in-store offer on top of the voucher.
    var offer: String?
    var id: String { name }

    var distance: String { km < 10 ? String(format: "%.1f km", km) : "\(Int(km)) km" }
}

struct GiftVoucher: Identifiable, Hashable {
    let id: String
    let brand: String
    let category: String
    let logo: VoucherLogo
    /// What the voucher costs on District.
    let price: Int
    /// What it is worth at the outlet.
    let worth: Int
    var left = 4
    let outlets: [VoucherOutlet]
    /// The brand's own colour; it lights the voucher sheet's header so each brand feels like itself.
    var tint = VoucherPalette.accentStrong

    var percentOff: Int { Int((Double(worth - price) / Double(worth) * 100).rounded(.down)) }
}

enum VoucherSection: String, CaseIterable, Identifiable {
    case apparel = "Apparel", footwear = "Footwear", jewellery = "Jewellery"
    var id: String { rawValue }
}

enum VoucherData {
    /// Figma "All eligible outlets" (3713:9396).
    private static let gurgaon = [
        VoucherOutlet(name: "Ireo Grand View High Street, Sector 58", km: 1.5),
        VoucherOutlet(name: "Ardee Mall, Ardee City", km: 2.5),
        VoucherOutlet(name: "M3M International Financial Center, Sector 66", km: 4.7),
        VoucherOutlet(name: "Worldmark, Sector 65", km: 10, offer: "Flat 10% OFF"),
    ]
    private static let malls = [
        VoucherOutlet(name: "Ambience Mall, DLF Phase 3", km: 3.2),
        VoucherOutlet(name: "DLF CyberHub, DLF Phase 2", km: 4.1, offer: "Flat 10% OFF"),
        VoucherOutlet(name: "Airia Mall, Sector 68", km: 6.8, hours: "11:00 AM to 10:00 PM", isOpen: false),
    ]

    static let peterEngland = GiftVoucher(id: "peter-england", brand: "Peter England", category: "Apparel | Fashion",
                                          logo: VoucherLogo(asset: "gv_logo_peter_england", size: CGSize(width: 156, height: 73), top: 24),
                                          price: 139, worth: 285, outlets: gurgaon, tint: Color(rgba: 0xC8102EFF))

    static let sections: [(VoucherSection, [GiftVoucher])] = [
        (.apparel, [
            GiftVoucher(id: "superdry", brand: "Superdry", category: "Apparel | Fashion",
                        logo: VoucherLogo(asset: "gv_logo_superdry", size: CGSize(width: 186, height: 105), top: 12.5, dx: 1),
                        price: 1199, worth: 2000, left: 6, outlets: malls, tint: Color(rgba: 0xFF5A1FFF)),
            GiftVoucher(id: "zara", brand: "Zara", category: "Apparel | Fashion",
                        logo: VoucherLogo(asset: "gv_logo_zara", size: CGSize(width: 159, height: 67), top: 26.6),
                        price: 1599, worth: 2500, left: 9, outlets: malls, tint: Color(rgba: 0xB8B8C0FF)),
        ]),
        (.footwear, [
            GiftVoucher(id: "birkenstock", brand: "Birkenstock", category: "Footwear | Fashion",
                        logo: VoucherLogo(asset: "gv_logo_birkenstock", size: CGSize(width: 119, height: 119), top: 0.4),
                        price: 2999, worth: 5000, left: 3, outlets: gurgaon, tint: Color(rgba: 0x2F55D4FF)),
            GiftVoucher(id: "zara-shoes", brand: "Zara", category: "Footwear | Fashion",
                        logo: VoucherLogo(asset: "gv_logo_zara", size: CGSize(width: 159, height: 67), top: 26.6, dx: 45),
                        price: 1049, worth: 1500, left: 12, outlets: malls, tint: Color(rgba: 0xB8B8C0FF)),
        ]),
        (.jewellery, [
            GiftVoucher(id: "giva", brand: "Giva", category: "Jewellery | Silver",
                        logo: VoucherLogo(asset: "gv_logo_giva", size: CGSize(width: 208, height: 122), top: -5.4, fills: true),
                        price: 1240, worth: 2000, left: 5, outlets: gurgaon, tint: Color(rgba: 0x3A4FD8FF)),
            GiftVoucher(id: "caratlane", brand: "CaratLane", category: "Jewellery | Gold & diamond",
                        logo: VoucherLogo(asset: "gv_logo_caratlane", size: CGSize(width: 189, height: 124), top: -7, fills: true, dx: -9.4),
                        price: 3100, worth: 5000, left: 2, outlets: malls, tint: Color(rgba: 0x9B4DCAFF)),
        ]),
    ]

    static let all: [GiftVoucher] = [peterEngland] + sections.flatMap(\.1)
    static func voucher(_ id: String) -> GiftVoucher? { all.first { $0.id == id } }

    /// Figma bottom sheet copy (first three), then the rest behind "View more".
    static let terms = [
        "Valid on a minimum purchase of two items",
        "Applicable on a minimum order value of ₹200",
        "Voucher can be redeemed at any outlet before its expiry",
        "Valid for 90 days from the date of purchase",
        "Cannot be combined with other vouchers or on sale merchandise",
        "One voucher per bill. Non-refundable once purchased",
    ]
}

/// Vouchers the user owns, shared by the landing rail and the voucher page.
@Observable
final class GiftVoucherWallet {
    var purchased: [String] = [VoucherData.peterEngland.id]
    var toast: String?
    /// The voucher whose details sheet is up.
    var sheet: GiftVoucher?
    /// Opens the sheet straight on its outlets list (debug launch, deep links).
    var sheetOpensOutlets = false

    func owns(_ voucher: GiftVoucher) -> Bool { purchased.contains(voucher.id) }

    func buy(_ voucher: GiftVoucher) {
        guard !owns(voucher) else { return }
        purchased.insert(voucher.id, at: 0)
        toast = "\(voucher.brand) voucher added to your vouchers"
    }

    /// Text code shown at the counter. No QR: the outlet keys it in.
    func code(for voucher: GiftVoucher) -> String {
        let letters = voucher.brand.uppercased().filter(\.isLetter)
        // Stable across launches (unlike `hashValue`).
        let seed = voucher.id.unicodeScalars.reduce(7) { ($0 * 31 + Int($1.value)) % 9000 }
        return "DV-" + String(letters.prefix(3)) + "-\(1000 + seed)"
    }
}

/// Identifies the flow for `readerCover`.
struct GiftVouchersPresentation: Identifiable {
    let id = "gift-vouchers"
}

// MARK: - Design canvas

/// Lays out art at Figma point positions on a fixed canvas, then scales it to the available width.
private struct DesignCanvas<Content: View>: View {
    let size: CGSize
    @ViewBuilder let content: Content

    var body: some View {
        Color.clear
            .aspectRatio(size.width / size.height, contentMode: .fit)
            .overlay(alignment: .topLeading) {
                GeometryReader { g in
                    ZStack(alignment: .topLeading) { content }
                        .frame(width: size.width, height: size.height, alignment: .topLeading)
                        .scaleEffect(g.size.width / size.width, anchor: .topLeading)
                }
            }
    }
}

// MARK: - Hero art

/// The voucher deals hero (Figma BG_DM + FG_DM): wash and texture, the 3D lockup, the
/// "Upto 80% OFF" band, burst stickers holding the shoes and accessories, sparkles and the % badge.
/// Drawn on the Figma's 390pt canvas; `top` shifts the foreground down for the Stores banner.
struct DealHeroArt: View {
    var height: CGFloat = 430
    var top: CGFloat = 0

    var body: some View {
        DesignCanvas(size: CGSize(width: 390, height: height)) {
            backdrop
            foreground.offset(y: top)
        }
        .accessibilityElement()
        .accessibilityLabel("Voucher deals. Upto 80% off on brand vouchers")
    }

    private var backdrop: some View {
        ZStack(alignment: .topLeading) {
            P.ink
            // The Figma clips the wash to a 427pt box that starts 80pt above the frame.
            ZStack(alignment: .topLeading) {
                V.heroWash
                Image("gv_hero_texture")
                    .resizable()
                    .scaledToFill()
                    .frame(width: 520, height: 347)
                    .clipped()
                    .opacity(0.63)
                    .blendMode(.multiply)
                    .position(x: 197, y: 53 + 173.5)
                Image("gv_hero_pattern")
                    .resizable()
                    .frame(width: 333, height: 485).dealTint()
                    .rotationEffect(.degrees(-90))
                    .blendMode(.softLight)
                    .position(x: 197, y: 86.5 + 166.5)
                Image("gv_hero_glow")
                    .resizable()
                    .frame(width: 415, height: 261).dealTint()
                    .blendMode(.plusLighter)
                    .position(x: 194, y: 435)
                V.heroFade
                    .frame(width: 542, height: 228)
                    .position(x: 236, y: 79 + 114)
                Image("gv_hero_flare")
                    .resizable()
                    .frame(width: 332, height: 222).dealTint()
                    .rotationEffect(.degrees(-13.27))
                    .blendMode(.overlay)
                    .position(x: 190, y: 230)
            }
            .frame(width: 394, height: 427, alignment: .topLeading)
            .clipped()
            .offset(x: -2, y: -80)
            // Mirrored fade back into the page under the band.
            V.heroFade
                .frame(width: 542, height: 243)
                .scaleEffect(y: -1)
                .position(x: 236, y: 104 + 121.5)
        }
        .frame(width: 390, height: height, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
    }

    private var foreground: some View {
        ZStack(alignment: .topLeading) {
            // "VOUCHER DEALS" in the Figma lockup's 3D style (rendered from Luckiest Guy), already blue.
            Image("gv_voucher_lockup")
                .resizable()
                .frame(width: 198, height: 132)
                .position(x: 194, y: 67 + 64)
            band
            Image("gv_burst_right")
                .resizable()
                .frame(width: 131, height: 112).dealTint()
                .rotationEffect(.degrees(-20.64))
                .position(x: 298 + 80.4, y: 129 + 73.7)
            Image("gv_burst_left")
                .resizable()
                .frame(width: 131, height: 112).dealTint()
                .scaleEffect(y: -1)
                .rotationEffect(.degrees(-159.36))
                .position(x: -54 + 80.4, y: 128 + 73.7)
            // Figma crops the cut-out to its centre.
            Image("gv_hero_shoes")
                .resizable()
                .frame(width: 141, height: 141)
                .offset(x: -25, y: -35)
                .frame(width: 101.4, height: 98.1, alignment: .topLeading)
                .clipped()
                .scaleEffect(x: -1)
                .position(x: -23 + 50.7, y: 146 + 49)
            Image("gv_hero_accessories")
                .resizable()
                .scaledToFill()
                .frame(width: 168, height: 105)
                .clipped()
                .scaleEffect(x: -1)
                .position(x: 276 + 84, y: 146 + 52.6)
            sparkle("gv_sparkle_mask_a", size: 25.7, x: 87, y: 144, angle: -12.96)
            sparkle("gv_sparkle_mask_b", size: 14, x: 79.6, y: 161.4, angle: 19.82)
            sparkle("gv_sparkle_mask_c", size: 18.3, x: 332, y: 206, angle: 61.6)
            sparkle("gv_sparkle_mask_d", size: 9.9, x: 329, y: 158, angle: -6.87)
            percentBadge.position(x: 296, y: 82)
        }
        .frame(width: 390, height: 290, alignment: .topLeading)
        .clipped()
        .accessibilityHidden(true)
    }

    private var band: some View {
        ZStack {
            Rectangle()
                .fill(V.band)
                .overlay(Rectangle().strokeBorder(Color(rgba: 0xE2EEFFFF), lineWidth: 0.5))
                .frame(width: 431, height: 54)
            VStack(spacing: 2) {
                Text("Upto 80% OFF")
                    .dropFont("ExtraBold", 16, relativeTo: .headline)
                Text("on brand vouchers")
                    .dropFont("SemiBold", 11.2, relativeTo: .caption)
            }
            .foregroundStyle(V.bandText)
            .shadow(color: .black, radius: 0, y: 0.8)
        }
        .position(x: 195, y: 179 + 27)
    }

    /// A Figma sparkle: the swirl gradient cut to a four-point star.
    private func sparkle(_ mask: String, size: CGFloat, x: CGFloat, y: CGFloat, angle: Double) -> some View {
        Image("gv_swirl_light")
            .resizable()
            .frame(width: size, height: size).dealTint()
            .mask(Image(mask).resizable())
            .rotationEffect(.degrees(angle))
            .position(x: x, y: y)
    }

    /// The scalloped % badge beside the lockup.
    private var percentBadge: some View {
        ZStack {
            Image("gv_swirl_deep")
                .resizable()
                .frame(width: 36.6, height: 34.9)
                .mask(Image("gv_percent_mask").resizable())
            Image("gv_percent_rim").resizable().frame(width: 33, height: 31.4)
            Image("gv_percent_glyph")
                .resizable()
                .frame(width: 18.9, height: 17.3)
                .rotationEffect(.degrees(5.49))
                .offset(x: 0.7, y: -0.6)
            Image("gv_percent_dot").resizable().frame(width: 3.2, height: 3.2).offset(x: -1.2, y: 12.6)
        }
        .dealTint()
    }
}

// MARK: - Stores banner

/// Stores-tab hero for gift voucher deals: the landing's hero art, set low under the tab header,
/// with the same 786×800 proportions as the other carousel pages.
struct GiftVouchersBanner: View {
    var action: () -> Void

    var body: some View {
        Color.clear
            .aspectRatio(786.0 / 800.0, contentMode: .fit)
            .overlay(alignment: .top) { DealHeroArt(height: 400, top: 44) }
            .overlay {
                LinearGradient(stops: [.init(color: .clear, location: 0.62), .init(color: P.ink.opacity(0.96), location: 0.86)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) { copy }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: R.cornerRadiusCorner24, bottomTrailingRadius: R.cornerRadiusCorner24))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Gift voucher deals. Upto 80% off on brand vouchers: buy a brand voucher on District and show it at the outlet")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the deals")
    }

    private var copy: some View {
        HStack(alignment: .bottom, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text("Gift voucher deals")
                    .dropFont("Medium", 12)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(V.stepText)
                Text("Buy brand vouchers for less, shop at the store.")
                    .backstageText(.body3)
                    .foregroundStyle(P.white70)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            HStack(spacing: R.spacingSpace4) {
                Text("Explore deals")
                Image(systemName: "arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .backstageText(.button3)
            .foregroundStyle(M.textInverse)
            .padding(.horizontal, R.spacingSpace16)
            .frame(height: 32)
            .background(M.surfaceInverse, in: Capsule())
            .fixedSize()
        }
        .padding(R.spacingSpace20)
        .padding(.bottom, R.spacingSpace12)
    }
}

// MARK: - Flow root

/// Gift voucher deals, from the Figma "See all landing" (3713:7386). Tapping a voucher opens its
/// details sheet (3713:9087); the eligible outlets (3713:9396) open inside that same sheet.
struct GiftVouchersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var wallet = GiftVoucherWallet()

    var body: some View {
        GiftVouchersLanding(close: { dismiss() })
            // One sheet per voucher. "View all" morphs it into the outlets list, so it never closes or stacks.
            .sheet(item: $wallet.sheet, onDismiss: { wallet.sheetOpensOutlets = false }) { VoucherSheet(voucher: $0) }
        .environment(wallet)
        .overlay(alignment: .bottom) { VoucherToast(text: $wallet.toast) }
        .preferredColorScheme(.dark)
        #if DEBUG
        .onAppear {
            let args = ProcessInfo.processInfo.arguments
            // `-giftVoucher <id>` opens its sheet; add `-giftViewAll` to open it on the outlets list.
            if let i = args.firstIndex(of: "-giftVoucher"), i + 1 < args.count, let v = VoucherData.voucher(args[i + 1]) {
                wallet.sheetOpensOutlets = args.contains("-giftViewAll")
                wallet.sheet = v
            }
        }
        #endif
    }
}

// MARK: - Landing

struct GiftVouchersLanding: View {
    @Environment(GiftVoucherWallet.self) private var wallet
    var close: () -> Void

    var body: some View {
        ScrollView(.vertical) {
            VStack(spacing: R.spacingSpace32) {
                ZStack(alignment: .top) {
                    DealHeroArt()
                    VoucherHowItWorks()
                        .padding(.top, 267)
                }
                // The first rail tucks into the hero's fade (Figma 391 of 430).
                .padding(.bottom, -39 - R.spacingSpace32 + R.spacingSpace8)
                purchased
                ForEach(VoucherData.sections, id: \.0) { section, vouchers in
                    rail(section.rawValue, vouchers)
                }
            }
            .padding(.bottom, R.spacingSpace48)
        }
        .scrollIndicators(.hidden)
        .ignoresSafeArea(edges: .top)
        .background(P.ink.ignoresSafeArea())
        .overlay(alignment: .topLeading) {
            GlassIconButton(systemName: "arrow.left", label: "Back", action: close)
                .padding(.leading, R.spacingSpace12)
        }
    }

    @ViewBuilder private var purchased: some View {
        let owned = wallet.purchased.compactMap(VoucherData.voucher)
        if !owned.isEmpty {
            VStack(spacing: R.spacingSpace16) {
                VoucherSectionLabel(title: "Your purchased vouchers")
                    .padding(.horizontal, R.spacingSpace16)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: R.spacingSpace16) {
                        ForEach(owned) { v in
                            Button { wallet.sheet = v } label: { PurchasedVoucherCard(voucher: v) }
                                .buttonStyle(PressableStyle())
                        }
                    }
                    .scrollTargetLayout()
                }
                .carousel()
                .animation(.snappy, value: wallet.purchased)
            }
        }
    }

    private func rail(_ title: String, _ vouchers: [GiftVoucher]) -> some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            Text(title)
                .dropFont("SemiBold", 18, relativeTo: .title3)
                .tracking(-0.18)
                .foregroundStyle(M.textPrimary)
                .padding(.horizontal, R.spacingSpace16)
                .accessibilityAddTraits(.isHeader)
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace16) {
                    ForEach(vouchers) { v in
                        Button { wallet.sheet = v } label: { VoucherDealCard(voucher: v) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
        }
    }
}

// MARK: - Shared pieces

/// Figma letter-spaced caps label between fading hairlines ("YOUR PURCHASED VOUCHERS", "TERMS & CONDITIONS").
struct VoucherSectionLabel: View {
    let title: String

    var body: some View {
        HStack(spacing: 0) {
            hairline(.leading)
            Text(title)
                .dropFont("Medium", 12, relativeTo: .subheadline)
                .tracking(1.2)
                .textCase(.uppercase)
                .foregroundStyle(M.textSecondary)
                .fixedSize()
                .padding(.horizontal, R.spacingSpace8)
                .accessibilityAddTraits(.isHeader)
            hairline(.trailing)
        }
        .frame(height: 18)
    }

    private func hairline(_ fade: Edge) -> some View {
        LinearGradient(colors: [M.borderModerate, M.borderModerate.opacity(0)],
                       startPoint: fade == .leading ? .trailing : .leading,
                       endPoint: fade == .leading ? .leading : .trailing)
            .frame(height: R.stroke1Px)
            .accessibilityHidden(true)
    }
}

/// "How it works": a blue rail through three numbered rings (Figma 3728:71870).
struct VoucherHowItWorks: View {
    private let steps = ["Buy Gift Voucher deals on District", "Step out & shop", "Show voucher at outlet."]

    var body: some View {
        VStack(spacing: 18) {
            HStack(spacing: 12) {
                bolt("gv_bolt_left")
                Text("How it works")
                    .dropFont("Medium", 12, relativeTo: .subheadline)
                    .tracking(1.2)
                    .textCase(.uppercase)
                    .foregroundStyle(LinearGradient(colors: [V.accent, V.accentPale], startPoint: .leading, endPoint: .trailing))
                    .accessibilityAddTraits(.isHeader)
                bolt("gv_bolt_right")
            }
            HStack(alignment: .top, spacing: 23) {
                ForEach(Array(steps.enumerated()), id: \.offset) { i, step in
                    VStack(spacing: 12) {
                        ZStack {
                            Image("gv_step_ring").resizable().frame(width: 24, height: 24).dealTint()
                            Text("\(i + 1)")
                                .dropFont("Bold", 12)
                                .foregroundStyle(V.accent)
                        }
                        Text(step)
                            .backstageText(.label3)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(V.stepText)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 85.3)
                    .accessibilityElement(children: .combine)
                }
            }
            .background(alignment: .top) {
                Capsule()
                    .fill(LinearGradient(colors: [V.deep, V.accentStrong], startPoint: .leading, endPoint: .trailing))
                    .frame(width: 222, height: 3)
                    .padding(.top, 10.5)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 302)
    }

    /// The glowing lightning marks either side of the kicker; the art includes its glow.
    private func bolt(_ asset: String) -> some View {
        Image(asset)
            .resizable()
            .frame(width: 47.8, height: 51.6)
            .frame(width: 7.8, height: 11.6)
            .dealTint()
            .accessibilityHidden(true)
    }
}

/// Blue price tag with zig-zag ends (Figma price block). `bright` is the deal-card variant on the
/// darker card; the notches are cut in that card's colour.
struct VoucherPriceTag: View {
    let price: Int
    var bright = false

    var body: some View {
        Text(rupees(price))
            .dropFont(bright ? "Bold" : "SemiBold", bright ? 18 : 16, relativeTo: .headline)
            .tracking(bright ? -0.36 : -0.16)
            .foregroundStyle(P.ink)
            .padding(.leading, bright ? 6 : 4)
            .padding(.trailing, bright ? 7 : 5)
            .frame(height: 24)
            .background(bright ? V.tagBright : V.tag)
            .overlay(alignment: .trailing) {
                Image(bright ? "gv_tag_edge_r2" : "gv_tag_edge_r").resizable().frame(width: bright ? 3 : 4, height: 31).offset(x: 1)
            }
            .overlay(alignment: .leading) {
                Image(bright ? "gv_tag_edge_l2" : "gv_tag_edge_l").resizable().frame(width: bright ? 3 : 4, height: 29)
                    .rotationEffect(.degrees(180)).offset(x: -1)
            }
            .clipped()
    }
}

/// Price tag, struck worth and an optional "Incl. taxes" note.
struct VoucherPriceRow: View {
    let voucher: GiftVoucher
    var bright = false
    var taxes = true

    var body: some View {
        HStack(spacing: bright ? 4 : 6) {
            VoucherPriceTag(price: voucher.price, bright: bright)
            Text(rupees(voucher.worth))
                .dropFont(bright ? "Medium" : "Regular", bright ? 11 : 12)
                .strikethrough()
                .foregroundStyle(V.strike)
                .accessibilityLabel("worth \(rupees(voucher.worth))")
            if taxes {
                Text("Incl. taxes")
                    .dropFont("Medium", 10, relativeTo: .caption2)
                    .foregroundStyle(M.textSecondary)
            }
        }
    }
}

/// The card's rolling status line: "% OFF" then "⏳ Only N left" (Figma ticker), one at a time.
struct VoucherTicker: View {
    let voucher: GiftVoucher
    var owned = false
    var size: CGFloat = 12
    @State private var index = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        // A ZStack, not a Group, so the clip below covers both lines while they swap.
        ZStack(alignment: .leading) {
            if owned {
                Label("Purchased", systemImage: "checkmark.seal.fill")
                    .labelStyle(TickerLabelStyle(gap: 4))
                    .foregroundStyle(V.accent)
            } else if index == 0 {
                HStack(spacing: 4) {
                    Image("gv_ic_tag").resizable().frame(width: size * 0.83, height: size * 0.83).dealTint().rotationEffect(.degrees(180)).scaleEffect(y: -1)
                    Text("\(voucher.percentOff)% OFF")
                }
                .foregroundStyle(V.accent)
                .transition(.push(from: .bottom))
            } else {
                HStack(spacing: 4) {
                    Text("⏳")
                    Text("Only \(voucher.left) left").foregroundStyle(V.warning)
                }
                .transition(.push(from: .bottom))
            }
        }
        .dropFont("Medium", size, relativeTo: .caption)
        .frame(height: size * 1.33, alignment: .leading)
        .clipped()
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(owned ? "Purchased" : "\(voucher.percentOff)% off. Only \(voucher.left) left")
        .task(id: owned) {
            guard !owned, !reduceMotion else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2.4))
                withAnimation(.snappy(duration: 0.4)) { index = 1 - index }
            }
        }
    }
}

private struct TickerLabelStyle: LabelStyle {
    var gap: CGFloat
    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: gap) { configuration.icon; configuration.title }
    }
}

/// Brand logo on a rounded tile: white behind transparent marks, edge to edge for logos with their own ground.
struct VoucherLogoTile: View {
    let logo: VoucherLogo
    var side: CGFloat = 84
    var radius: CGFloat = 12

    var body: some View {
        ZStack {
            Color.white
            Image(logo.asset)
                .resizable()
                .aspectRatio(contentMode: logo.fills ? .fill : .fit)
                .padding(logo.fills ? 0 : side * 0.06)
        }
        .frame(width: side, height: side)
        .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
        .accessibilityHidden(true)
    }
}

/// The tilted "N% OFF" burst sticker on deal cards.
struct VoucherBurst: View {
    let percent: Int
    var scale: CGFloat = 1

    var body: some View {
        ZStack {
            Image("gv_burst_card")
                .resizable()
                .frame(width: 67.7, height: 59.3).dealTint()
                .scaleEffect(y: -1)
                .rotationEffect(.degrees(-159.36))
            VStack(spacing: -3) {
                Text("\(percent)%").dropFont("Bold", 15.6).tracking(-0.22)
                Text("OFF").dropFont("Bold", 10.4).tracking(-0.22)
            }
            .foregroundStyle(P.ink)
            .rotationEffect(.degrees(10.1))
            .offset(x: 1, y: 2)
        }
        .frame(width: 83, height: 76)
        .scaleEffect(scale)
        .accessibilityHidden(true)
    }
}

// MARK: - Cards

/// "Your purchased vouchers" card (Figma card 6): name, ticker, price tag; logo tile on the right.
struct PurchasedVoucherCard: View {
    let voucher: GiftVoucher

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(alignment: .leading, spacing: 0) {
                Text(voucher.brand)
                    .backstageText(.title3)
                    .foregroundStyle(M.textPrimary)
                    .lineLimit(1)
                Spacer(minLength: R.spacingSpace8)
                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    VoucherTicker(voucher: voucher)
                    VoucherPriceRow(voucher: voucher)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VoucherLogoTile(logo: voucher.logo)
        }
        .frame(height: 84)
        .padding(R.spacingSpace12)
        .frame(width: 311)
        .background(M.backgroundSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20, style: .continuous).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        .accessibilityElement(children: .combine)
        .accessibilityHint("Opens the voucher")
    }
}

/// Category rail card (Figma 3735:73721): logo on a white panel, glows, brand and price, % burst.
struct VoucherDealCard: View {
    let voucher: GiftVoucher

    var body: some View {
        ZStack(alignment: .topLeading) {
            panel
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(voucher.brand.uppercased())
                        .backstageText(.label3)
                        .foregroundStyle(M.textSecondary)
                    Text("Gift voucher")
                        .backstageText(.title3)
                        .foregroundStyle(M.textPrimary)
                }
                VoucherPriceRow(voucher: voucher, bright: true, taxes: false)
            }
            .padding(.leading, 10.2)
            .padding(.top, 128)
            VoucherBurst(percent: voucher.percentOff)
                .position(x: 166.6, y: 122.4)
        }
        .frame(width: 208, height: 222, alignment: .topLeading)
        .background(alignment: .topLeading) {
            ZStack(alignment: .topLeading) {
                Image("gv_card_glow_a").resizable().frame(width: 300, height: 300).dealTint().position(x: 175, y: 40)
                Image("gv_card_glow_b").resizable().frame(width: 347, height: 347).position(x: 54.6, y: 31.8)
            }
            .allowsHitTesting(false)
        }
        .background(P.ink)
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24, style: .continuous).strokeBorder(M.borderModerate, lineWidth: 1.075))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(voucher.brand) gift voucher, \(rupees(voucher.price)), worth \(rupees(voucher.worth)), \(voucher.percentOff)% off")
        .accessibilityAddTraits(.isButton)
    }

    private var panel: some View {
        ZStack(alignment: .top) {
            Color.white
            Image(voucher.logo.asset)
                .resizable()
                .scaledToFill()
                .frame(width: voucher.logo.size.width, height: voucher.logo.size.height)
                .clipped()
                .offset(x: voucher.logo.dx, y: voucher.logo.top)
        }
        .frame(width: 208.3, height: 120, alignment: .top)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: 12.9, topTrailingRadius: 12.9))
        .offset(x: -1.2, y: -1.7)
    }
}

// MARK: - Toast

/// Short confirmation that floats above the content and clears itself.
struct VoucherToast: View {
    @Binding var text: String?

    var body: some View {
        Group {
            if let text {
                HStack(spacing: R.spacingSpace8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(V.accent)
                    Text(text).backstageText(.label2).foregroundStyle(M.textPrimary)
                }
                .padding(.horizontal, R.spacingSpace16)
                .frame(minHeight: 44)
                .liquidGlass(in: Capsule())
                .padding(.bottom, 104)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .task(id: text) {
                    try? await Task.sleep(for: .seconds(2.6))
                    withAnimation(.snappy) { self.text = nil }
                }
                .accessibilityAddTraits(.updatesFrequently)
            }
        }
        .animation(.snappy, value: text)
    }
}

#Preview {
    GiftVouchersView()
}
