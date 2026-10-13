import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive
private typealias P = HPDropPalette

// MARK: - Campaign palette

/// SG × Hardik Pandya campaign colours: a cool silver foil over graphite, with the willow and the
/// red ball for product glows. Like `DominantColor`, these are campaign colours, not UI tokens, and
/// are used only on the drop banner and page.
enum HPDropPalette {
    static let ink = Color(rgba: 0x08090AFF)
    /// Page ground from the campaign Figma.
    static let page = Color(rgba: 0x0B0B0CFF)
    static let graphite = Color(rgba: 0x1D2025FF)
    static let silver = Color(rgba: 0xC4C8CFFF)
    static let silverLight = Color(rgba: 0xF5F6F8FF)
    static let silverDeep = Color(rgba: 0x6B7079FF)
    static let willow = Color(rgba: 0xEADBBEFF)
    static let cherry = Color(rgba: 0x8A1A26FF)
    /// The gold foil of the HP33 bolt on the bags.
    static let gold = Color(rgba: 0xC9A24BFF)

    static let foil = LinearGradient(colors: [silverLight, silver, silverDeep], startPoint: .topLeading, endPoint: .bottomTrailing)
    static let foilVertical = LinearGradient(colors: [silverLight, silver, silverDeep], startPoint: .top, endPoint: .bottom)

    // Drop page, from the campaign Figma.
    static let haloCore = Color(rgba: 0x737373FF)
    static let haloEdge = Color(rgba: 0xD9D9D9FF)
    static let cherryHalo = [Color(rgba: 0x5A2129FF), Color(rgba: 0x96676EFF)]
    static let goldHalo = [Color(rgba: 0xEFCD72FF), Color(rgba: 0x513924FF)]
    static let band = Color(rgba: 0x8A8A8AFF)
    static let bandEdge = Color(rgba: 0x99999900)
    static let sparkWhite = Color(rgba: 0xF3F3F3FF)
    static let champagneGlow = Color(rgba: 0xF8E99633)
    static let glowFloor = Color(rgba: 0xB3B3B3FF)
    static let cardEdge = Color(rgba: 0xF6F6F929)
    static let captionText = Color(rgba: 0xF3F3F7A3)
    static let benefitGlow = Color(rgba: 0x353535FF)
    static let stepPanel = Color(rgba: 0x151517FF)
    static let stepCard = Color(rgba: 0x151515FF)
    static let skuCard = Color(rgba: 0x171718FF)
    static let reserveFloor = Color(rgba: 0x070706FF)
    static let buttonInk = Color(rgba: 0x0F0F0FFF)

    /// Eyebrows and rule labels: white into grey.
    static let sheen = LinearGradient(colors: [.white, Color(rgba: 0x999999FF)], startPoint: .leading, endPoint: .trailing)
    /// Benefit titles: off-white into a warm stone.
    static let warmSheen = LinearGradient(colors: [Color(rgba: 0xF7F7F7FF), Color(rgba: 0xC0B2A7FF)], startPoint: .topLeading, endPoint: .bottomTrailing)
    /// The "Reserve now" brushed metal.
    static let metal = LinearGradient(stops: [.init(color: Color(rgba: 0x717171FF), location: 0.01), .init(color: Color(rgba: 0x9E9898FF), location: 0.1),
                                              .init(color: Color(rgba: 0xD6D6D6FF), location: 0.27), .init(color: Color(rgba: 0xD6D6D6FF), location: 0.83),
                                              .init(color: Color(rgba: 0x9E9E9EFF), location: 0.98), .init(color: Color(rgba: 0x9A9A9AFF), location: 1)],
                                      startPoint: .leading, endPoint: .trailing)
}

// MARK: - Stores banner

/// Stores-tab hero banner for the drop: the campaign's finished artwork ("DM_Banner") as one image.
/// The whole banner opens the drop.
struct HPDropBanner: View {
    var action: () -> Void

    var body: some View {
        Image("hp_banner")
            .resizable()
            .scaledToFit()
            .frame(maxWidth: .infinity)
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: R.cornerRadiusCorner24, bottomTrailingRadius: R.cornerRadiusCorner24))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("SG × Hardik Pandya: Born to be 33. Exclusive on District. Reveals 13 October")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the drop")
    }
}

/// The official SG shield × HP bolt lockup.
struct HPLockup: View {
    var height: CGFloat = 32

    var body: some View {
        Image("hp_lockup")
            .resizable().scaledToFit()
            .frame(height: height)
            .foregroundStyle(M.textWhite)
            .accessibilityLabel("SG × Hardik Pandya")
    }
}

/// "Only on district" seal for the drop's exclusivity, in the District wordmark.
struct DistrictExclusiveBadge: View {
    var height: CGFloat = 28

    var body: some View {
        HStack(spacing: height * 0.22) {
            Text("ONLY ON")
                .font(.custom("BeVietnamPro-Bold", fixedSize: height * 0.36))
                .tracking(height * 0.04)
                .foregroundStyle(P.ink)
            Image("hp_district_wordmark")
                .resizable().scaledToFit()
                .frame(height: height * 0.46)
                .foregroundStyle(P.ink)
        }
        .padding(.horizontal, height * 0.4)
        .frame(height: height)
        .background(P.foil, in: Capsule())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Only on District")
    }
}

// MARK: - Drop page

/// The SG × Hardik Pandya birthday drop, built from the campaign Figma ("Other cities", node
/// 16364:272): the portrait header, title, exclusive band and lockup, date and venue, Hardik's edit,
/// District benefits, how to shop, the collection carousel, help, and a closing logo moment.
struct HPDropView: View {
    @State private var notified = false
    @State private var scrollY: CGFloat = 0
    @State private var selected: HPProduct?
    @State private var focused: HPProduct.ID?
    @State private var railWidth: CGFloat = 402
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: R.spacingSpace0) {
                    header
                    VStack(spacing: R.spacingSpace40) {
                        intro
                        hardiksEdit.revealOnScroll()
                        benefits.revealOnScroll()
                        VStack(spacing: 50) {
                            howToShop.revealOnScroll()
                            collection.id(Self.collectionID)
                        }
                        help.revealOnScroll()
                    }
                    // The title rides up over the portrait's fade, as in the Figma.
                    .padding(.top, -22)
                    finale
                }
                .onScrollOffset { scrollY = $0 }
            }
            .scrollIndicators(.hidden)
            .ignoresSafeArea(edges: .top)
            .background(P.page.ignoresSafeArea())
            .overlay(alignment: .top) { topFade }
            .overlay(alignment: .top) { topBar }
            .overlay(alignment: .bottom) {
                ReserveBar {
                    withAnimation(.smooth(duration: 0.6)) { proxy.scrollTo(Self.collectionID, anchor: .top) }
                }
            }
        }
        .sheet(item: $selected) { HPProductSheet(product: $0, notified: $notified) }
        .sensoryFeedback(.success, trigger: notified) { _, new in new }
        .preferredColorScheme(.dark)
    }

    private static let collectionID = "collection"
    private static let headerHeight: CGFloat = 378

    // MARK: Top bar

    private var collapsed: Bool { scrollY < -320 }

    /// Keeps the status bar and controls legible once the header has scrolled away.
    private var topFade: some View {
        LinearGradient(stops: [.init(color: P.page, location: 0), .init(color: P.page.opacity(0.92), location: 0.6), .init(color: P.page.opacity(0), location: 1)],
                       startPoint: .top, endPoint: .bottom)
            .frame(height: 140)
            .ignoresSafeArea()
            .opacity(collapsed ? 1 : 0)
            .animation(.easeInOut(duration: 0.25), value: collapsed)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private var topBar: some View {
        HStack {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }
            Spacer()
            HPLockup(height: 24)
                .opacity(collapsed ? 1 : 0)
                .offset(y: collapsed ? 0 : 8)
            Spacer()
            ShareLink(item: "SG × Hardik Pandya: Born to be 33, only on District. \(HPDrop.dropDateShort)") {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 44, height: 44)
                    .liquidGlass(in: Circle(), interactive: true, clear: true)
            }
            .accessibilityLabel("Share")
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.bottom, R.spacingSpace8)
        .animation(.easeInOut(duration: 0.25), value: collapsed)
    }

    // MARK: Header

    /// Hardik's birthday portrait, a cutout over a soft spotlight, full-bleed under the status bar.
    /// It stretches when pulled down, drifts at half speed as the page scrolls, and fades into the
    /// page at the bottom.
    private var header: some View {
        Color.clear
            .frame(height: Self.headerHeight)
            .background(alignment: .bottom) {
                Halo(width: 351, height: 263, blur: 72, opacity: 0.26).offset(y: 50)
            }
            .overlay(alignment: .topLeading) {
                Image("hp_header_cutout")
                    .resizable().scaledToFit()
                    .containerRelativeFrame(.horizontal) { w, _ in w * 1.0711 }
                    .fixedSize(horizontal: false, vertical: true)
                    .offset(y: -Self.headerHeight * 0.1597)
                    .visualEffect { v, proxy in
                        let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        return v
                            .scaleEffect(y > 0 ? 1 + y / 400 : 1, anchor: .top)
                            .offset(y: y > 0 ? -y : -y * 0.5)
                    }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(stops: [.init(color: P.page.opacity(0), location: 0.127), .init(color: P.page, location: 0.908)],
                               startPoint: .top, endPoint: .bottom)
                    .frame(height: 61)
            }
            .accessibilityElement()
            .accessibilityLabel("Hardik Pandya smiling as a hand brings in 33 birthday candles")
            .accessibilityAddTraits(.isImage)
    }

    // MARK: Title, exclusive band, lockup, date and venue

    private var intro: some View {
        VStack(spacing: R.spacingSpace24) {
            VStack(spacing: R.spacingSpace16) {
                VStack(spacing: R.spacingSpace8) {
                    // Figma sets this in Roc Grotesk Wide Bold, which isn't bundled.
                    Text("BORN TO BE \(Text("३३").font(.custom("BeVietnamPro-ExtraBold", size: 38.8, relativeTo: .largeTitle)))")
                        .font(.custom("BeVietnamPro-ExtraBold", size: 34, relativeTo: .largeTitle))
                        .tracking(0.34)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                        .textureFill("hp_tex_born")
                        .accessibilityLabel("Born to be 33")
                        .accessibilityAddTraits(.isHeader)
                    Text("A collection that brings together SG’s cricket legacy and Hardik’s signature style.")
                        .campaignText("BeVietnamPro-Regular", 14, lineHeight: 22, relativeTo: .subheadline)
                        .foregroundStyle(M.textPrimary.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 308)
                }
                exclusiveBand
            }
            HPLockup(height: 59)
            eventCard
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    /// "Exclusively on District" between two sparks, on a silver band that fades at both ends.
    private var exclusiveBand: some View {
        HStack(spacing: 10) {
            Image("hp_spark")
            Text("EXCLUSIVELY ON DISTRICT")
                .campaignText("BeVietnamPro-Medium", 14, lineHeight: 18, relativeTo: .subheadline)
                .textureFill("hp_tex_exclusive")
                .shadow(color: P.champagneGlow, radius: 16, y: 4)
            Image("hp_spark")
        }
        .frame(maxWidth: .infinity)
        .frame(height: 34)
        .background {
            LinearGradient(stops: [.init(color: P.bandEdge, location: 0), .init(color: P.band, location: 0.488), .init(color: P.bandEdge, location: 1)],
                           startPoint: .leading, endPoint: .trailing)
                .blendMode(.hardLight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Exclusively on District")
    }

    private var eventCard: some View {
        VStack(spacing: R.spacingSpace16) {
            eventRow(icon: "hp_ic_calendar", title: HPDrop.dropDateLong, detail: HPDrop.storeOpens)
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            eventRow(icon: "hp_ic_location", title: HPDrop.venue, detail: nil)
        }
        .padding(R.spacingSpace16)
        .glassCard(radius: R.cornerRadiusCorner24)
    }

    private func eventRow(icon: String, title: String, detail: String?) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Image(icon)
                .frame(width: 40, height: 40)
                .background(M.surfaceSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .campaignText("BeVietnamPro-Medium", 14, lineHeight: 18, relativeTo: .subheadline)
                    .foregroundStyle(M.textPrimary)
                if let detail {
                    Text(detail).backstageText(.body3).foregroundStyle(M.textPrimary.opacity(0.5))
                }
            }
            Spacer(minLength: 0)
            Image("hp_ic_chevron").accessibilityHidden(true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Hardik's edit

    private var hardiksEdit: some View {
        VStack(spacing: R.spacingSpace16) {
            SectionHeading(eyebrow: "The 33 story", title: "Hardik’s edit", texture: "hp_tex_edit")
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace12) {
                    ForEach(HPDrop.edit, id: \.image) { EditCard(item: $0) }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
        .background { Halo(width: 349.5, height: 244.5, blur: 89, opacity: 0.26) }
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(spacing: R.spacingSpace16) {
            SparkRule(text: "District benefits")
            VStack(spacing: R.spacingSpace12) {
                ForEach(HPDrop.benefits, id: \.title) { BenefitRow(benefit: $0) }
            }
        }
        .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: How to shop

    private var howToShop: some View {
        VStack(spacing: R.spacingSpace12) {
            FoilTitle(text: "How to shop the drop", texture: "hp_tex_howto", font: "BeVietnamPro-SemiBold", size: 22, lineHeight: 28, tracking: -0.22)
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(HPDrop.steps.enumerated()), id: \.offset) { i, step in
                    if i > 0 { Image("hp_step_connector").accessibilityHidden(true) }
                    StepRow(step: step)
                }
            }
            .padding(R.spacingSpace12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(P.stepCard, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        }
        .padding(.top, R.spacingSpace16)
        .padding([.horizontal, .bottom], R.spacingSpace8)
        .background(P.stepPanel, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: Collection

    /// A centred carousel: the focused piece at full size, its neighbours slightly smaller and dimmer.
    private var collection: some View {
        VStack(spacing: R.spacingSpace16) {
            VStack(spacing: R.spacingSpace24) {
                SectionHeading(eyebrow: "Birthday drop", title: "Full collection", texture: "hp_tex_collection")
                ScrollView(.horizontal) {
                    LazyHStack(spacing: R.spacingSpace4) {
                        ForEach(HPDrop.products) { product in
                            Button { selected = product } label: { SKUCard(product: product) }
                                .buttonStyle(PressableStyle())
                                .visualEffect { v, proxy in
                                    let frame = proxy.frame(in: .scrollView(axis: .horizontal))
                                    let width = proxy.bounds(of: .scrollView(axis: .horizontal))?.width ?? frame.width
                                    // 0 for the centred card, 1 for its neighbours and beyond.
                                    let t = min(1, abs(frame.midX - width / 2) / frame.width)
                                    return v.scaleEffect(1 - 0.1 * t).opacity(1 - 0.2 * t)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .scrollPosition(id: $focused, anchor: .center)
                .contentMargins(.horizontal, max(R.spacingSpace16, (railWidth - SKUCard.width) / 2), for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
                .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { railWidth = $0 }
            }
            PageDots(count: HPDrop.products.count, index: HPDrop.products.firstIndex { $0.id == focused } ?? 0)
        }
    }

    // MARK: FAQ and T&C

    private var help: some View {
        VStack(spacing: R.spacingSpace16) {
            helpRow(icon: "hp_ic_faq", title: "Frequently asked questions")
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            helpRow(icon: "hp_ic_terms", title: "Terms and conditions")
        }
        .padding(R.spacingSpace16)
        .background(M.backgroundPrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .padding(.horizontal, R.spacingSpace16)
    }

    private func helpRow(icon: String, title: String) -> some View {
        Button {} label: {
            HStack(spacing: R.spacingSpace16) {
                Image(icon).accessibilityHidden(true)
                Text(title)
                    .campaignText("BeVietnamPro-Medium", 14, lineHeight: 20, tracking: -0.24, relativeTo: .subheadline)
                    .foregroundStyle(M.textPrimary)
                Spacer()
                Image("hp_ic_chevron_muted").accessibilityHidden(true)
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Logo

    /// The sign-off: the SG × HP lockup and "Only on District" over a giant, ghosted ३३.
    private var finale: some View {
        ZStack(alignment: .top) {
            // Figma sets the ३३ in Cabinet Grotesk Bold, which isn't bundled.
            Text("३३")
                .font(.system(size: 303, weight: .bold))
                .tracking(-33.4)
                .foregroundStyle(M.textWhite.opacity(0.04))
                .fixedSize()
                .accessibilityHidden(true)
            Halo(width: 283, height: 198, blur: 72, opacity: 0.26)
                .frame(maxHeight: .infinity, alignment: .bottom)
            VStack(spacing: 18) {
                HPLockup(height: 65)
                HStack(spacing: 10) {
                    Text("ONLY ON").campaignText("BeVietnamPro-Regular", 16, lineHeight: 24, relativeTo: .body)
                    Image("hp_district_wordmark")
                        .resizable().scaledToFit()
                        .frame(height: 16)
                }
                .foregroundStyle(M.textWhite)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Only on District")
            }
            .padding(.top, 147)
        }
        .frame(width: 283, height: 410)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - Page pieces

/// Be Vietnam Pro at a campaign size with the Figma line height, scaled with Dynamic Type. The
/// campaign file uses District's 14pt body and label sizes, which differ from the Backstage styles.
private struct CampaignText: ViewModifier {
    let font: String
    let size: CGFloat
    let lineHeight: CGFloat?
    let tracking: CGFloat
    @ScaledMetric private var scale: CGFloat

    init(font: String, size: CGFloat, lineHeight: CGFloat?, tracking: CGFloat, relativeTo: Font.TextStyle) {
        self.font = font
        self.size = size
        self.lineHeight = lineHeight
        self.tracking = tracking
        _scale = ScaledMetric(wrappedValue: 1, relativeTo: relativeTo)
    }

    func body(content: Content) -> some View {
        content
            .font(.custom(font, fixedSize: size * scale))
            .tracking(tracking * scale)
            .lineSpacing(lineHeight.map { max(0, ($0 - size * 1.265) * scale) } ?? 0)
    }
}

/// Fills text with one of the campaign's foil textures (the Figma's image text fills).
private struct TextureFill: ViewModifier {
    let texture: String

    func body(content: Content) -> some View {
        content
            .foregroundStyle(.clear)
            .overlay {
                Image(texture).resizable().mask { content }.accessibilityHidden(true)
            }
    }
}

private extension View {
    func campaignText(_ font: String, _ size: CGFloat, lineHeight: CGFloat? = nil, tracking: CGFloat = 0, relativeTo: Font.TextStyle) -> some View {
        modifier(CampaignText(font: font, size: size, lineHeight: lineHeight, tracking: tracking, relativeTo: relativeTo))
    }

    func textureFill(_ texture: String) -> some View { modifier(TextureFill(texture: texture)) }
}

/// The Figma's blurred elliptical spotlights behind the header, sections and products.
private struct Halo: View {
    var colors: [Color] = [P.haloCore, P.haloEdge]
    let width: CGFloat
    let height: CGFloat
    let blur: CGFloat
    let opacity: Double

    var body: some View {
        Ellipse()
            .fill(EllipticalGradient(colors: colors))
            .frame(width: width, height: height)
            .blur(radius: blur)
            .opacity(opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// Foil-textured title over a soft, blurred copy of itself.
private struct FoilTitle: View {
    let text: String
    let texture: String
    var font = "BeVietnamPro-Bold"
    var size: CGFloat = 24
    var lineHeight: CGFloat = 30
    var tracking: CGFloat = -0.48
    /// The blurred copy sits slightly above the title in the section headings.
    var glowOffset: CGFloat = 0

    var body: some View {
        label
            .textureFill(texture)
            .background {
                label
                    .foregroundStyle(LinearGradient(colors: [M.textPrimary, P.glowFloor], startPoint: .top, endPoint: .bottom))
                    .blur(radius: 7)
                    .opacity(0.5)
                    .offset(y: glowOffset)
                    .accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
    }

    private var label: some View {
        Text(text)
            .campaignText(font, size, lineHeight: lineHeight, tracking: tracking, relativeTo: .title2)
            .multilineTextAlignment(.center)
    }
}

/// Uppercase eyebrow in a silver sheen with a faint champagne glow.
private struct Eyebrow: View {
    let text: String

    var body: some View {
        Text(text.uppercased())
            .campaignText("BeVietnamPro-Medium", 12, tracking: 1.2, relativeTo: .caption)
            .foregroundStyle(P.sheen)
            .shadow(color: P.champagneGlow, radius: 16, y: 4)
    }
}

/// Eyebrow over a foil title (Hardik's edit, Full collection).
private struct SectionHeading: View {
    let eyebrow: String
    let title: String
    let texture: String

    var body: some View {
        VStack(spacing: R.spacingSpace12) {
            Eyebrow(text: eyebrow)
            FoilTitle(text: title, texture: texture, glowOffset: -8)
        }
        .padding(.horizontal, R.spacingSpace16)
    }
}

/// Uppercase label between two sparks and fading hairlines (District benefits).
private struct SparkRule: View {
    let text: String

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            hairline(fadingTo: .leading)
            Image("hp_spark")
            Text(text.uppercased())
                .campaignText("BeVietnamPro-SemiBold", 16, lineHeight: 22, tracking: 0.8, relativeTo: .headline)
                .foregroundStyle(P.sheen)
                .shadow(color: P.champagneGlow, radius: 16, y: 4)
                .fixedSize()
                .accessibilityAddTraits(.isHeader)
            Image("hp_spark")
            hairline(fadingTo: .trailing)
        }
    }

    private func hairline(fadingTo end: UnitPoint) -> some View {
        LinearGradient(colors: [P.sparkWhite, P.sparkWhite.opacity(0)], startPoint: end == .leading ? .trailing : .leading, endPoint: end)
            .frame(height: 0.5)
            .opacity(0.5)
    }
}

/// A card in Hardik's edit: his photo full-bleed, with a title and line over a blurred scrim.
private struct EditCard: View {
    let item: HPEdit
    private static let size = CGSize(width: 232, height: 317)

    var body: some View {
        Color.clear
            .frame(width: Self.size.width, height: Self.size.height)
            .overlay(alignment: .topLeading) {
                // The Figma crop, in card points.
                Image(item.image)
                    .resizable().scaledToFill()
                    .frame(width: item.crop.width, height: item.crop.height)
                    .offset(x: item.crop.minX, y: item.crop.minY)
            }
            .overlay(alignment: .bottom) { caption }
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24).strokeBorder(P.cardEdge, lineWidth: R.stroke1Px))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(item.title). \(item.text)")
    }

    private var caption: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace4) {
            Text(item.title)
                .campaignText("BeVietnamPro-SemiBold", 16, lineHeight: 22, tracking: -0.16, relativeTo: .headline)
                .foregroundStyle(M.textWhite)
                .lineLimit(1)
            Text(item.text)
                .backstageText(.body3)
                .foregroundStyle(P.captionText)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, 26)
        .padding(.bottom, R.spacingSpace16)
        .background {
            ZStack {
                Rectangle().fill(.ultraThinMaterial)
                    .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.35)))
                LinearGradient(colors: [.black.opacity(0), .black.opacity(0.75)], startPoint: .top, endPoint: .bottom)
            }
        }
    }
}

/// One District benefit: its 3D icon, then a warm-silver title and a line, on a glass card.
private struct BenefitRow: View {
    let benefit: HPBenefit

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            Image(benefit.image)
                .resizable().scaledToFit()
                .frame(width: 32, height: 32)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(benefit.title).backstageText(.title4).foregroundStyle(P.warmSheen)
                Text(benefit.detail).backstageText(.body3).foregroundStyle(M.textPrimary.opacity(0.5))
            }
            Spacer(minLength: 0)
        }
        .padding(R.spacingSpace16)
        .background(alignment: .topLeading) {
            Ellipse().fill(P.benefitGlow).frame(width: 185, height: 90).blur(radius: 22).opacity(0.5).offset(x: -1, y: -7)
        }
        .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
        .glassCard(radius: R.cornerRadiusCorner16)
        .accessibilityElement(children: .combine)
    }
}

/// A how-to step: its icon tile, lit from below, and the instruction.
private struct StepRow: View {
    let step: HPStep

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace16) {
            Image(step.icon)
                .overlay(alignment: .bottom) {
                    Ellipse().fill(M.textPrimary).frame(width: 40, height: 11).blur(radius: 12).opacity(0.4).offset(y: 2.9)
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner8))
                .accessibilityHidden(true)
            Text(step.text)
                .campaignText("BeVietnamPro-Regular", 14, lineHeight: 22, relativeTo: .subheadline)
                .foregroundStyle(M.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

/// A collection piece: the product under its coloured halo, with the name and price centred below.
private struct SKUCard: View {
    static let width: CGFloat = 272
    let product: HPProduct

    var body: some View {
        VStack(spacing: R.spacingSpace0) {
            Image(product.cardImage)
                .resizable().scaledToFit()
                .frame(maxWidth: 230, maxHeight: product.cardImageHeight)
                .rotationEffect(.degrees(product.cardTilt))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.top, R.spacingSpace12)
            VStack(spacing: R.spacingSpace8) {
                Text(product.name)
                    .campaignText("BeVietnamPro-SemiBold", 16, lineHeight: 22, tracking: -0.16, relativeTo: .headline)
                    .multilineTextAlignment(.center)
                    .lineLimit(2, reservesSpace: true)
                    .frame(maxWidth: 217)
                Text(product.price)
                    .campaignText("BeVietnamPro-Regular", 14, lineHeight: 22, relativeTo: .subheadline)
            }
            .foregroundStyle(M.textWhite)
            .padding(.horizontal, R.spacingSpace12)
            .padding(.vertical, R.spacingSpace16)
            .frame(maxWidth: .infinity)
        }
        .frame(width: Self.width, height: 398)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner24)
                .fill(P.skuCard)
                .overlay(alignment: .top) {
                    Halo(colors: product.halo, width: 283, height: 198, blur: 72, opacity: 0.4).offset(y: -71)
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        }
        .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(product.name), \(product.price)")
        .accessibilityHint("Shows details and specs")
    }
}

/// Carousel position: a pill for the focused card, dots for the rest.
private struct PageDots: View {
    let count: Int
    let index: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(M.textPrimary)
                    .frame(width: i == index ? 18 : 6, height: 6)
                    .opacity(i == index ? 1 : 0.32)
            }
        }
        .animation(.snappy, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Piece \(index + 1) of \(count)")
    }
}

/// Brushed-silver "Reserve now" pinned to the bottom over a fade to black (Figma's button).
private struct ReserveBar: View {
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("Reserve now").frame(maxWidth: .infinity)
        }
        .buttonStyle(MetalButtonStyle())
        .accessibilityHint("Jumps to the full collection")
        .padding(.horizontal, R.spacingSpace20)
        .padding(.top, R.spacingSpace20)
        .padding(.bottom, R.spacingSpace8)
        .background {
            LinearGradient(stops: [.init(color: P.reserveFloor.opacity(0), location: 0.07), .init(color: P.reserveFloor, location: 0.68)],
                           startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
        }
    }
}

private struct MetalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .body))
            .foregroundStyle(P.buttonInk)
            .frame(minHeight: 52)
            .background(P.metal, in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

/// The product sheet's call to action: get notified when the drop goes live.
private struct NotifyButton: View {
    @Binding var notified: Bool

    var body: some View {
        Button {
            withAnimation(.snappy) { notified.toggle() }
        } label: {
            HStack(spacing: R.spacingSpace8) {
                Image(systemName: notified ? "checkmark.circle.fill" : "bell.fill").font(.system(size: 15, weight: .semibold))
                Text(notified ? "You're on the list" : "Notify me")
            }
            .frame(maxWidth: .infinity)
            .contentTransition(.symbolEffect(.replace))
        }
        .buttonStyle(NotifyButtonStyle(notified: notified))
        .accessibilityHint(notified ? "Turns off the drop alert" : "Alerts you when the drop goes live")
    }
}

private struct NotifyButtonStyle: ButtonStyle {
    let notified: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .backstageText(.label1)
            .foregroundStyle(notified ? P.silverLight : P.ink)
            .frame(minHeight: 52)
            .background {
                if notified {
                    Capsule().fill(P.silver.opacity(0.14)).overlay(Capsule().strokeBorder(P.silver.opacity(0.6), lineWidth: R.stroke1Px))
                } else {
                    Capsule().fill(P.foil)
                }
            }
            .shadow(color: P.silver.opacity(notified ? 0 : 0.35), radius: 16, y: 4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
            .animation(.snappy(duration: 0.2), value: configuration.isPressed)
    }
}

// MARK: - Product sheet

/// A collection piece in full: hero cutout, price, the five feature bullets and its specs.
struct HPProductSheet: View {
    let product: HPProduct
    @Binding var notified: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: R.spacingSpace24) {
                ZStack {
                    RadialGradient(colors: [product.glow.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 170)
                    Image(product.image)
                        .resizable().scaledToFit()
                        .rotationEffect(.degrees(product.kind == .bat ? 35 : 0))
                        .padding(product.kind == .ball ? 56 : R.spacingSpace24)
                        .shadow(color: .black.opacity(0.6), radius: 20, y: 14)
                }
                .frame(height: 300)
                .frame(maxWidth: .infinity)
                .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: R.spacingSpace8) {
                    if let tag = product.tag {
                        Text(tag).font(.custom("BeVietnamPro-SemiBold", fixedSize: 10)).tracking(1.6).foregroundStyle(P.silver)
                    }
                    Text(product.name).backstageText(.heading3).foregroundStyle(M.textPrimary).accessibilityAddTraits(.isHeader)
                    DistrictExclusiveBadge(height: 22)
                    HStack(alignment: .firstTextBaseline, spacing: R.spacingSpace8) {
                        Text(product.price).backstageText(.title2).foregroundStyle(P.silverLight)
                        Text("MRP, incl. of all taxes").backstageText(.body3).foregroundStyle(M.textTertiary)
                    }
                    Text(product.summary).backstageText(.body2).foregroundStyle(M.textSecondary).padding(.top, R.spacingSpace4)
                }

                VStack(alignment: .leading, spacing: R.spacingSpace16) {
                    ForEach(product.bullets, id: \.title) { b in
                        HStack(alignment: .top, spacing: R.spacingSpace12) {
                            Image(systemName: "seal.fill")
                                .font(.system(size: 13))
                                .foregroundStyle(P.foil)
                                .padding(.top, 3)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(b.title).backstageText(.label1).foregroundStyle(M.textPrimary)
                                Text(b.text).backstageText(.body3).foregroundStyle(M.textSecondary)
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                VStack(spacing: R.spacingSpace0) {
                    ForEach(Array(product.specs.enumerated()), id: \.offset) { i, spec in
                        if i > 0 { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                        HStack {
                            Text(spec.0).backstageText(.body3).foregroundStyle(M.textSecondary)
                            Spacer()
                            Text(spec.1).backstageText(.label2).foregroundStyle(M.textPrimary).multilineTextAlignment(.trailing)
                        }
                        .padding(.vertical, R.spacingSpace12)
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(.horizontal, R.spacingSpace16)
                .background(M.surfacePrimary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner16))
            }
            .padding(R.spacingSpace16)
            .padding(.bottom, 96)
        }
        .scrollIndicators(.hidden)
        .background(LinearGradient(colors: [P.graphite, P.ink], startPoint: .top, endPoint: .center).ignoresSafeArea())
        .overlay(alignment: .topTrailing) {
            GlassIconButton(systemName: "xmark", label: "Close") { dismiss() }.padding(R.spacingSpace16)
        }
        .overlay(alignment: .bottom) {
            NotifyButton(notified: $notified)
                .padding(R.spacingSpace16)
                .background(LinearGradient(colors: [P.ink.opacity(0), P.ink], startPoint: .top, endPoint: .center).ignoresSafeArea())
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
        .presentationBackground(P.ink)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Scroll offset

private extension View {

    /// Reports the vertical content offset (0 at rest, negative as the page scrolls up).
    func onScrollOffset(_ action: @escaping (CGFloat) -> Void) -> some View {
        background(alignment: .top) {
            Color.clear
                .frame(height: 0)
                .onGeometryChange(for: CGFloat.self) { $0.frame(in: .scrollView(axis: .vertical)).minY } action: { action($0) }
        }
    }

    /// The Figma card: translucent graphite, a hairline edge and a soft layered drop shadow.
    func glassCard(radius: CGFloat) -> some View {
        background(LinearGradient(colors: [Color(rgba: 0x131316B3), Color(rgba: 0x1E1E20B3)], startPoint: .top, endPoint: .bottom),
                   in: RoundedRectangle(cornerRadius: radius))
            .overlay(RoundedRectangle(cornerRadius: radius).strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px))
            .shadow(color: .black.opacity(0.1), radius: 6, y: 6)
            .shadow(color: .black.opacity(0.09), radius: 12, y: 24)
    }
}

// MARK: - Data

struct HPProduct: Identifiable {
    enum Kind { case bat, ball, bag }
    struct Bullet { let title: String; let text: String }

    let id: String          // SKU
    let name: String
    let kind: Kind
    let image: String
    let price: String
    let tag: String?
    let glow: Color
    let summary: String
    let bullets: [Bullet]
    let specs: [(String, String)]
}

extension HPProduct {
    /// The collection card's shot: the angled studio cutouts for the bats.
    var cardImage: String { kind == .bat ? image + "_angle" : image }

    var cardImageHeight: CGFloat {
        switch kind {
        case .bat: 253
        case .ball: 220
        case .bag: 265
        }
    }

    /// The small tilts the Figma gives each bat.
    var cardTilt: Double {
        switch id {
        case "SG01CR131843": -7.82
        case "SG01CR131845": 6.12
        default: 0
        }
    }

    /// The card's halo: cherry for the red ball, gold for the bags, silver otherwise.
    var halo: [Color] {
        if glow == P.cherry { return P.cherryHalo }
        if kind == .bag { return P.goldHalo }
        return [P.haloCore, P.haloEdge]
    }
}

/// A card in Hardik's edit.
struct HPEdit {
    let image: String
    let title: String
    let text: String
    /// The photo's frame inside the 232 × 317 card, from the Figma.
    let crop: CGRect
}

struct HPBenefit {
    let image: String
    let title: String
    let detail: String
}

struct HPStep {
    /// Icon tile asset.
    let icon: String
    let text: String
}

/// Identifies the drop for `readerCover`.
struct HPDropPresentation: Identifiable {
    let id = "sg-hp-10-years"
}

/// Drop content. Products, prices, copy and specs come from the SG × HP inventory sheet; the
/// times, venue, edit, benefits and steps come from the campaign Figma.
enum HPDrop {
    // Hardik's 33rd birthday (born 11 Oct 1993). The Figma shows "19th September" as a
    // placeholder date; the 2 PM drop, 11 AM store opening and venue are from the Figma.
    static let dropDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 11; c.hour = 14
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")
        return Calendar(identifier: .gregorian).date(from: c) ?? .now
    }()
    static let dropDateShort = "Drops 11 Oct, 2 PM"
    static let dropDateLong = "11th October | 2:00 PM onwards"
    static let storeOpens = "Store opens at 11 AM"
    static let venue = "FutureWorld, DLF Avenue Mall Saket, New Delhi 110017, India"

    static let products: [HPProduct] = [
        HPProduct(
            id: "SG01CR131843", name: "SG 10 Years × HP English Willow Bat", kind: .bat, image: "hp_bat_10years",
            price: "₹2,19,999", tag: "LIMITED EDITION", glow: P.willow,
            summary: "Handcrafted from Grade 1 Select English Willow for maximum durability and explosive hitting power, with thick edges for a massive sweet spot and a shock-absorbing Singapore cane handle.",
            bullets: [
                .init(title: "Premium willow", text: "Handcrafted from top-tier wood for maximum durability and powerful hits."),
                .init(title: "Huge sweet spot", text: "Thick edges and a special shape give a massive, forgiving hitting area."),
                .init(title: "Shock-proof handle", text: "Premium Singapore cane absorbs painful vibrations on impact."),
                .init(title: "No-slip grip", text: "A comfortable handle wrap for a firm, confident hold."),
                .init(title: "Lightweight design", text: "Under 1180 grams for fast, effortless swings."),
            ],
            specs: [("Willow", "Grade 1 Select English Willow"), ("Size", "SH (short handle)"), ("Weight", "Under 1180 g"),
                    ("Dimensions", "85 × 11 × 3.8 cm"), ("SKU", "SG01CR131843")]),
        HPProduct(
            id: "SG01CR131845", name: "SG HP Privee Replica \"Kung Fu Pandya\" Bat", kind: .bat, image: "hp_bat_kungfu",
            price: "₹69,999", tag: "PLAYER REPLICA", glow: P.willow,
            summary: "A high-performance, handcrafted bat for elite players. Rigorously selected, air-dried Premium Grade 1 English Willow for exceptional quality, durability and grain structure.",
            bullets: [
                .init(title: "Premium Grade 1 English Willow", text: "Air-dried, rigorously selected willow with a superior grain structure."),
                .init(title: "Optimised power transfer", text: "A classic profile with thick edges and a curved blade for an expansive sweet spot."),
                .init(title: "Enhanced feel and stability", text: "Imported cane handle with shock-absorbing cork inserts for comfort and control."),
                .init(title: "Dependable performance", text: "Excellent balance and a light pickup, built for every format."),
                .init(title: "Precision shot control", text: "A profile that helps you place strokes across the field with confidence."),
            ],
            specs: [("Willow", "Grade 1 English Willow"), ("Size", "SH (short handle)"), ("Weight", "Under 1180 g"),
                    ("Dimensions", "85 × 11 × 3.8 cm"), ("SKU", "SG01CR131845")]),
        HPProduct(
            id: "SG01CR120587", name: "SG HP 33 Red Cricket Leather Ball", kind: .ball, image: "hp_ball_red",
            price: "₹599", tag: "SIGNATURE SERIES", glow: P.cherry,
            summary: "Built to last a minimum of 50 overs, with a waterproof core and precise machine stitching for consistent play in all weather.",
            bullets: Self.ballBullets,
            specs: [("Colour", "Red"), ("Format", "Tests, first-class, day cricket"), ("Weight", "196 g"), ("SKU", "SG01CR120587")]),
        HPProduct(
            id: "SG01CR120586", name: "SG HP 33 White Cricket Leather Ball", kind: .ball, image: "hp_ball_white",
            price: "₹699", tag: "SIGNATURE SERIES", glow: P.willow,
            summary: "Built to last a minimum of 50 overs, with a waterproof core and precise machine stitching for consistent play in all weather.",
            bullets: Self.ballBullets,
            specs: [("Colour", "White"), ("Format", "T20, ODI, day-night cricket"), ("Weight", "196 g"), ("SKU", "SG01CR120586")]),
        HPProduct(
            id: "SG01CRKB0552", name: "SG HP Wheelie Duffle Kit Bag", kind: .bag, image: "hp_bag_wheelie",
            price: "₹6,999", tag: nil, glow: P.gold,
            summary: "A heavy-duty match-day kit bag in leatherette, with a cushioned bat slot, a leg-guard pocket and a ball pocket to keep pro gear organised.",
            bullets: [
                .init(title: "Durable leatherette build", text: "Sturdy material with a clean look that lasts."),
                .init(title: "Cushioned bat slot", text: "A fully padded sleeve keeps your bat safe from damage."),
                .init(title: "Leg guard pocket", text: "A dedicated external pocket for bulky leg guards."),
                .init(title: "Dedicated ball pocket", text: "A separate compartment so balls don't roll around."),
                .init(title: "Comfortable carrying layout", text: "Structured to maximise storage and travel easily."),
            ],
            specs: [("Size", "Medium"), ("Dimensions", "97 × 34 × 34 cm"), ("Weight", "3.5 kg"), ("Colour", "Black"), ("SKU", "SG01CRKB0552")]),
        HPProduct(
            id: "SG01CRKB0554", name: "SG HP Junior Duffle Kit Bag", kind: .bag, image: "hp_bag_junior",
            price: "₹1,199", tag: nil, glow: P.gold,
            summary: "A compact, lightweight kit bag for young players, with a dedicated bat compartment and a separate shoe pocket.",
            bullets: [
                .init(title: "Compact and lightweight", text: "Sized and weighted for young cricketers."),
                .init(title: "Premium sturdy build", text: "High-quality materials with a neat, professional look."),
                .init(title: "Secure bat compartment", text: "A dedicated space keeps the bat tucked away and protected."),
                .init(title: "Separate shoe pocket", text: "Keeps muddy shoes away from clean whites."),
                .init(title: "Effortless transport", text: "A simple layout that makes carrying gear stress-free."),
            ],
            specs: [("Size", "Junior"), ("Dimensions", "71 × 23 × 34 cm"), ("Weight", "1.25 kg"), ("Colour", "Black"), ("SKU", "SG01CRKB0554")]),
        HPProduct(
            id: "SG01CRKB0538", name: "SG HP33 Gym Bag", kind: .bag, image: "hp_bag_gym",
            price: "₹6,999", tag: nil, glow: P.gold,
            summary: "Leatherette and Carbonium outside, velvet-lined inside, with a top organiser, a ventilated shoe compartment and room for a weekend away.",
            bullets: [
                .init(title: "Premium build", text: "Durable Leatherette and Carbonium with a soft velvet-lined interior."),
                .init(title: "Top organiser compartment", text: "Keeps your phone, wallet and keys neatly in place."),
                .init(title: "Dedicated shoe compartment", text: "A ventilated side pocket keeps shoes away from clean gear."),
                .init(title: "Accessories pocket", text: "Room for cables, toiletries or supplements."),
                .init(title: "Spacious main compartment", text: "Fits clothing, towels and gym equipment."),
            ],
            specs: [("Dimensions", "67 × 29 × 33 cm"), ("Materials", "Leatherette, Carbonium, velvet"), ("SKU", "SG01CRKB0538")]),
        HPProduct(
            id: "SG01CR110627", name: "SG HP 33 Premium Backpack", kind: .bag, image: "hp_backpack",
            price: "₹5,999", tag: nil, glow: P.gold,
            summary: "An airport-ready carryall in eco-friendly vegan leather blended with recycled polyester, with HP 33 branding and a laptop sleeve.",
            bullets: [
                .init(title: "Secure storage", text: "Two magnetic side pockets plus snap-button closures."),
                .init(title: "Laptop-friendly", text: "A dedicated laptop space for work or academy sessions."),
                .init(title: "HP 33 branding", text: "Inspired by SG's legacy in cricket gear."),
                .init(title: "Travel-ready", text: "11\" × 16.5\" × 5\" and just 1.036 kg, ideal as a carry-on."),
                .init(title: "Material", text: "Vegan leather blended with recycled polyester."),
            ],
            specs: [("Dimensions", "11\" × 16.5\" × 5\""), ("Weight", "1.036 kg"), ("SKU", "SG01CR110627")]),
    ]

    private static let ballBullets: [HPProduct.Bullet] = [
        .init(title: "Premium leatherette", text: "A durable, high-quality alternative to real leather."),
        .init(title: "Budget-friendly", text: "Professional-level performance for players, schools and clubs."),
        .init(title: "50+ overs durability", text: "Keeps its shape through high-intensity matches."),
        .init(title: "100% waterproof", text: "Protected against moisture, ideal for wet weather."),
        .init(title: "Machine-stitched seam", text: "Stays perfectly round and boosts swing potential."),
    ]

    // The Figma repeats one placeholder caption on every card ("Be the Part of Hardil’s bday by
    // buying her merch"); this is it with the name and pronoun fixed, until final copy lands.
    private static let editCaption = "Be part of Hardik’s birthday by buying his merch"
    private static let portraitCrop = CGRect(x: -4.32, y: -0.84, width: 237.63, height: 316.84)

    static let edit: [HPEdit] = [
        HPEdit(image: "hp_edit_1", title: "Hardik X SG", text: editCaption, crop: CGRect(x: -94.53, y: -28.35, width: 453.67, height: 344.35)),
        HPEdit(image: "hp_edit_2", title: "Hardik X SG", text: editCaption, crop: CGRect(x: -16.84, y: -27.77, width: 296.58, height: 370.71)),
        HPEdit(image: "hp_edit_3", title: "Hardik X SG", text: editCaption, crop: portraitCrop),
        HPEdit(image: "hp_edit_4", title: "Hardik X SG", text: editCaption, crop: CGRect(x: -20.82, y: -49.25, width: 292.22, height: 365.25)),
        HPEdit(image: "hp_edit_5", title: "Hardik X SG", text: editCaption, crop: portraitCrop),
        HPEdit(image: "hp_edit_6", title: "Hardik X SG", text: editCaption, crop: portraitCrop),
    ]

    static let benefits: [HPBenefit] = [
        HPBenefit(image: "hp_icon_tote", title: "Exclusive Collection", detail: "Explore the SG × Hardik collection"),
        HPBenefit(image: "hp_icon_discount", title: "10% off & No-Cost EMI", detail: "Up to ₹4,000 OFF + Pay in 3 instalments"),
        HPBenefit(image: "hp_icon_poster", title: "Hardik Pandya Signed Poster", detail: "Own a piece of the iconic collab"),
    ]

    static let steps: [HPStep] = [
        HPStep(icon: "hp_step_explore", text: "Explore the iconic collection exclusively on District"),
        HPStep(icon: "hp_step_book", text: "Book your slot to shop the collection in-store"),
        HPStep(icon: "hp_step_pay", text: "Pay via District & get up to ₹4,000 OFF. No-Cost EMI options available."),
    ]
}

#Preview("Drop") {
    HPDropView()
}

#Preview("Banner") {
    HPDropBanner {}
        .background(BackstageTokens.Mapped.backgroundPrimary)
        .preferredColorScheme(.dark)
}
