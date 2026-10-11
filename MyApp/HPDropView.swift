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
}

/// Anton, the campaign's condensed display face (numbers, the HP33 wordmark).
private func anton(_ size: CGFloat) -> Font { .custom("Anton-Regular", fixedSize: size) }

// MARK: - Stores banner

/// Stores-tab hero banner for the drop, drawn natively at the one8 banner's proportions so the copy
/// stays sharp and "Know more" is a real button.
struct HPDropBanner: View {
    var action: () -> Void
    /// Same proportions as the campaign artwork slot (804 × 782).
    private let aspect: CGFloat = 804.0 / 782.0

    var body: some View {
        Color.clear
            .aspectRatio(aspect, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay { GeometryReader { artwork(in: $0.size) } }
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: R.cornerRadiusCorner24, bottomTrailingRadius: R.cornerRadiusCorner24))
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("SG × Hardik Pandya, 10 years. Hardik's birthday drop, only on District, \(HPDrop.dropDateShort)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens the drop")
    }

    private func artwork(in size: CGSize) -> some View {
        let w = size.width, h = size.height
        return ZStack {
            LinearGradient(colors: [P.ink, P.ink, P.graphite], startPoint: .top, endPoint: .bottom)
            RadialGradient(colors: [P.silver.opacity(0.42), P.silver.opacity(0.08), .clear],
                           center: UnitPoint(x: 0.7, y: 0.6), startRadius: 0, endRadius: w * 0.62)

            Image("hp_hardik")
                .resizable().scaledToFill()
                .frame(width: w * 0.7, height: h * 1.02, alignment: .top)
                .clipped()
                .mask(LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.45)],
                                     startPoint: .leading, endPoint: .trailing))
                .position(x: w * 0.65, y: h * 0.12 + h * 0.51)

            // Ink over the status bar and header, and a warm floor under the pill.
            LinearGradient(stops: [.init(color: P.ink, location: 0), .init(color: P.ink.opacity(0), location: 0.3),
                                   .init(color: P.ink.opacity(0), location: 0.72), .init(color: P.ink.opacity(0.85), location: 1)],
                           startPoint: .top, endPoint: .bottom)

            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                HPLockup(height: 36)
                Text("10 YEARS")
                    .font(anton(58))
                    .foregroundStyle(P.foil)
                    .padding(.top, R.spacingSpace8)
                Text("HARDIK'S BIRTHDAY DROP")
                    .font(.custom("BeVietnamPro-SemiBold", fixedSize: 11))
                    .tracking(2.2)
                    .foregroundStyle(M.textWhite)
                HStack(spacing: R.spacingSpace8) {
                    DistrictExclusiveBadge(height: 24)
                    Text(HPDrop.dropDateChip)
                        .backstageText(.label3)
                        .foregroundStyle(P.silverLight)
                        .padding(.horizontal, R.spacingSpace8)
                        .frame(height: 24)
                        .overlay(Capsule().strokeBorder(P.silver.opacity(0.5), lineWidth: R.stroke1Px))
                }
                .padding(.top, R.spacingSpace8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.leading, R.spacingSpace20)
            .padding(.top, h * 0.36)

            // Sized like the one8 banner's pill (about 26% of the width, 7% of the height); the whole
            // banner is the tap target.
            HStack(spacing: 2) {
                Text("Know more")
                Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold))
            }
            .font(.custom("BeVietnamPro-SemiBold", fixedSize: 12.5))
            .foregroundStyle(M.textBlack)
            .padding(.horizontal, R.spacingSpace16)
            .frame(height: h * 0.07)
            .background(M.iconWhite, in: Capsule())
            .position(x: w * 0.5, y: h * 0.913)
        }
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

/// The SG × Hardik Pandya birthday drop. Sections follow the campaign brief: header image, title,
/// subtitle, exclusive line, date and location, the Hardik rail, District benefits, how to shop,
/// the collection rail, help, and a closing logo moment.
struct HPDropView: View {
    @State private var notified = false
    @State private var scrollY: CGFloat = 0
    @State private var selected: HPProduct?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical) {
                VStack(spacing: R.spacingSpace56) {
                    VStack(spacing: R.spacingSpace24) {
                        header
                        intro
                        eventCard
                    }
                    hardikRail.revealOnScroll()
                    benefits.revealOnScroll()
                    howToShop.revealOnScroll()
                    collection.id(Self.collectionID)
                    help.revealOnScroll()
                    finale.revealOnScroll()
                }
                .padding(.bottom, 96)
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
            ShareLink(item: "SG × Hardik Pandya: the HP33 birthday drop, only on District. \(HPDrop.dropDateShort)") {
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

    // MARK: Header image

    /// Hardik's birthday portrait, full-bleed under the status bar. It stretches when pulled down,
    /// drifts at half speed as the page scrolls, and melts into the page at the bottom.
    private var header: some View {
        Color.clear
            .frame(height: 400)
            .overlay(alignment: .top) {
                Image("hp_header")
                    .resizable().scaledToFill()
                    .frame(height: 400, alignment: .top)
                    .visualEffect { v, proxy in
                        let y = proxy.frame(in: .scrollView(axis: .vertical)).minY
                        return v
                            .scaleEffect(y > 0 ? 1 + y / 400 : 1, anchor: .top)
                            .offset(y: y > 0 ? -y : -y * 0.5)
                    }
            }
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(colors: [P.page.opacity(0), P.page], startPoint: .top, endPoint: .bottom)
                    .frame(height: 140)
            }
            .accessibilityElement()
            .accessibilityLabel("Hardik Pandya smiling beside a 33 birthday candle")
            .accessibilityAddTraits(.isImage)
    }

    // MARK: Title, subtitle, exclusive

    private var intro: some View {
        VStack(spacing: R.spacingSpace32) {
            VStack(spacing: R.spacingSpace12) {
                Text("SG × HP33 · BIRTHDAY DROP")
                    .font(.custom("BeVietnamPro-Medium", size: 12, relativeTo: .caption))
                    .tracking(1.2)
                    .foregroundStyle(M.textTertiary)
                GlowTitle(text: "10 years. One Legacy.", size: 26)
                Text("Hardik turns 33 on 11 October. To celebrate a decade with SG, the HP33 collection drops on his birthday.")
                    .backstageText(.body2)
                    .foregroundStyle(M.textPrimary.opacity(0.5))
                    .multilineTextAlignment(.center)
                    .lineSpacing(2)
                    .frame(maxWidth: 300)
            }
            VStack(spacing: R.spacingSpace24) {
                ExclusiveLine()
                HPLockup(height: 52)
            }
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.top, -R.spacingSpace24)
        .padding(.bottom, R.spacingSpace8)
    }

    // MARK: Date and location

    private var eventCard: some View {
        VStack(spacing: R.spacingSpace16) {
            eventRow(icon: "calendar", title: HPDrop.dropDateLong) {
                DropsIn(target: HPDrop.dropDate)
            }
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            eventRow(icon: "mappin.and.ellipse", title: HPDrop.stores) {
                Text(HPDrop.storesDetail)
            }
        }
        .padding(R.spacingSpace16)
        .glassCard(radius: R.cornerRadiusCorner24)
        .padding(.horizontal, R.spacingSpace16)
    }

    private func eventRow<Detail: View>(icon: String, title: String, @ViewBuilder detail: () -> Detail) -> some View {
        HStack(spacing: R.spacingSpace12) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(M.iconPrimary)
                .frame(width: 40, height: 40)
                .background(M.surfaceSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
            VStack(alignment: .leading, spacing: 2) {
                Text(title).backstageText(.label1).foregroundStyle(M.textPrimary)
                detail().backstageText(.body3).foregroundStyle(M.textPrimary.opacity(0.5))
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(M.iconTertiary)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Hardik Pandya rail

    private var hardikRail: some View {
        VStack(spacing: R.spacingSpace24) {
            SectionTitle(eyebrow: "Hardik Pandya", title: "The Hardik story")
            ScrollView(.horizontal) {
                LazyHStack(spacing: R.spacingSpace12) {
                    ForEach(HPDrop.facts, id: \.image) { HardikCard(fact: $0) }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: Benefits

    private var benefits: some View {
        VStack(spacing: R.spacingSpace20) {
            SparkleRule(text: "District benefits")
            VStack(spacing: R.spacingSpace12) {
                ForEach(HPDrop.benefits, id: \.title) { BenefitCard(benefit: $0) }
            }
            .padding(.horizontal, R.spacingSpace16)
        }
    }

    // MARK: How to shop

    private var howToShop: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace20) {
            Text("How to shop the drop")
                .font(.custom("BeVietnamPro-SemiBold", size: 20, relativeTo: .title2))
                .tracking(-0.4)
                .foregroundStyle(M.textPrimary)
                .frame(maxWidth: .infinity)
                .accessibilityAddTraits(.isHeader)
            VStack(alignment: .leading, spacing: R.spacingSpace0) {
                ForEach(Array(HPDrop.steps.enumerated()), id: \.offset) { i, step in
                    StepRow(number: i + 1, step: step, isLast: i == HPDrop.steps.count - 1)
                }
            }
        }
        .padding(R.spacingSpace20)
        .glassCard(radius: R.cornerRadiusCorner24)
        .padding(.horizontal, R.spacingSpace16)
    }

    // MARK: Collection

    private var collection: some View {
        VStack(spacing: R.spacingSpace24) {
            SectionTitle(eyebrow: "Birthday drop", title: "Full collection")
            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: R.spacingSpace12) {
                    ForEach(Array(HPDrop.products.enumerated()), id: \.element.id) { i, product in
                        Button { selected = product } label: { SKUCard(product: product, number: i + 1, count: HPDrop.products.count) }
                            .buttonStyle(PressableStyle())
                    }
                }
                .scrollTargetLayout()
            }
            .contentMargins(.horizontal, R.spacingSpace16, for: .scrollContent)
            .scrollTargetBehavior(.viewAligned)
            .scrollIndicators(.hidden)
        }
    }

    // MARK: FAQ and T&C

    private var help: some View {
        VStack(spacing: R.spacingSpace16) {
            helpRow(icon: "questionmark.circle", title: "Frequently asked questions")
            Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px)
            helpRow(icon: "doc.text", title: "Terms and conditions")
        }
        .padding(R.spacingSpace16)
        .glassCard(radius: R.cornerRadiusCorner16)
        .padding(.horizontal, R.spacingSpace16)
    }

    private func helpRow(icon: String, title: String) -> some View {
        Button {} label: {
            HStack(spacing: R.spacingSpace16) {
                Image(systemName: icon).font(.system(size: 18)).foregroundStyle(M.iconSecondary)
                Text(title).backstageText(.label1).foregroundStyle(M.textPrimary)
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 13, weight: .semibold)).foregroundStyle(M.iconTertiary)
            }
            .frame(minHeight: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Logo

    /// The sign-off: the SG × HP lockup on a stage of a giant, ghosted 33.
    private var finale: some View {
        ZStack {
            Text("33")
                .font(anton(300))
                .foregroundStyle(LinearGradient(colors: [.white.opacity(0.07), .white.opacity(0)], startPoint: .top, endPoint: .bottom))
                .accessibilityHidden(true)
            Ellipse()
                .fill(P.silver.opacity(0.16))
                .frame(width: 280, height: 160)
                .blur(radius: 60)
                .accessibilityHidden(true)
            VStack(spacing: R.spacingSpace16) {
                HPLockup(height: 60)
                GlowTitle(text: "Happy 33rd, Hardik", size: 22)
                HStack(spacing: R.spacingSpace8) {
                    Text("ONLY ON")
                        .font(.custom("BeVietnamPro-SemiBold", size: 10, relativeTo: .caption2))
                        .tracking(1.6)
                    Image("hp_district_wordmark")
                        .resizable().scaledToFit()
                        .frame(height: 13)
                }
                .foregroundStyle(M.textTertiary)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Only on District")
            }
        }
        .frame(height: 340)
        .frame(maxWidth: .infinity)
        .clipped()
    }
}

// MARK: - Page pieces

/// Bold title in bright silver with a white bloom behind it and a soft spotlight under it.
private struct GlowTitle: View {
    let text: String
    var size: CGFloat = 28

    private var fill: LinearGradient {
        LinearGradient(stops: [.init(color: .white, location: 0), .init(color: .white, location: 0.45), .init(color: Color(rgba: 0xC9CACFFF), location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }

    var body: some View {
        title
            .foregroundStyle(fill)
            .shadow(color: .white.opacity(0.35), radius: 1)
            .background {
                title.foregroundStyle(.white).blur(radius: size * 0.4).opacity(0.4).accessibilityHidden(true)
            }
            .background {
                Ellipse().fill(.white.opacity(0.07)).frame(width: size * 9, height: size * 2.4).blur(radius: 30).accessibilityHidden(true)
            }
            .accessibilityAddTraits(.isHeader)
    }

    private var title: some View {
        Text(text)
            .font(.custom("BeVietnamPro-Bold", size: size, relativeTo: .title))
            .tracking(-size * 0.03)
            .multilineTextAlignment(.center)
    }
}

/// Small uppercase eyebrow over a glow title.
private struct SectionTitle: View {
    let eyebrow: String
    let title: String

    var body: some View {
        VStack(spacing: R.spacingSpace8) {
            Text(eyebrow.uppercased())
                .font(.custom("BeVietnamPro-Medium", size: 12, relativeTo: .caption))
                .tracking(1.2)
                .foregroundStyle(M.textSecondary)
            GlowTitle(text: title, size: 28)
        }
        .padding(.horizontal, R.spacingSpace16)
    }
}

/// Four-point spark from the campaign artwork.
private struct Spark: Shape {
    func path(in r: CGRect) -> Path {
        var p = Path()
        let c = CGPoint(x: r.midX, y: r.midY)
        p.move(to: CGPoint(x: r.midX, y: r.minY))
        p.addQuadCurve(to: CGPoint(x: r.maxX, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.maxY), control: c)
        p.addQuadCurve(to: CGPoint(x: r.minX, y: c.y), control: c)
        p.addQuadCurve(to: CGPoint(x: r.midX, y: r.minY), control: c)
        return p
    }
}

/// Uppercase label between two sparks and fading hairlines (section headers).
private struct SparkleRule: View {
    let text: String

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.3)], startPoint: .leading, endPoint: .trailing).frame(height: R.stroke1Px)
            SparkLabel(text: text)
            LinearGradient(colors: [.white.opacity(0.3), .white.opacity(0)], startPoint: .leading, endPoint: .trailing).frame(height: R.stroke1Px)
        }
        .padding(.horizontal, R.spacingSpace16)
    }
}

private struct SparkLabel: View {
    let text: String

    var body: some View {
        HStack(spacing: R.spacingSpace8) {
            Spark().fill(Color(rgba: 0xF3F3F3FF)).frame(width: 10, height: 14)
            Text(text.uppercased())
                .font(.custom("BeVietnamPro-Medium", size: 12, relativeTo: .footnote))
                .tracking(1.6)
                .foregroundStyle(LinearGradient(colors: [.white, Color(rgba: 0x999999FF)], startPoint: .leading, endPoint: .trailing))
                .shadow(color: Color(rgba: 0xF8E99633), radius: 16, y: 4)
                .accessibilityAddTraits(.isHeader)
            Spark().fill(Color(rgba: 0xF3F3F3FF)).frame(width: 10, height: 14)
        }
        .fixedSize()
    }
}

/// "Exclusively on District", quiet: sparked label on a faint silver band that fades at both ends.
private struct ExclusiveLine: View {
    var body: some View {
        SparkLabel(text: "Exclusively on District")
            .frame(maxWidth: .infinity)
            .frame(height: 28)
            .background {
                LinearGradient(colors: [Color(rgba: 0x99999900), Color(rgba: 0x8A8A8A4D), Color(rgba: 0x99999900)], startPoint: .leading, endPoint: .trailing)
            }
            .overlay(alignment: .top) { hairline }
            .overlay(alignment: .bottom) { hairline }
    }

    private var hairline: some View {
        LinearGradient(colors: [.white.opacity(0), .white.opacity(0.16), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
            .frame(height: R.stroke1Px)
    }
}

/// Live "Drops in 1d 19h 11m"; "Live now" once it passes.
private struct DropsIn: View {
    let target: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let s = max(0, Int(target.timeIntervalSince(context.date)))
            if s == 0 {
                Text("Live now · store opens at 11 AM")
            } else {
                Text("Drops in \(s / 86_400)d \(s % 86_400 / 3600)h \(s % 3600 / 60)m \(s % 60)s")
                    .monospacedDigit()
                    .contentTransition(.numericText(countsDown: true))
                    .animation(.snappy, value: s)
            }
        }
    }
}

/// A card in the Hardik rail: his photo full-bleed, with a tag, title and line over a scrim.
private struct HardikCard: View {
    let fact: HPFact

    var body: some View {
        Color.clear
            .frame(width: 240, height: 320)
            .overlay(alignment: .top) {
                Image(fact.image)
                    .resizable().scaledToFill()
                    .frame(width: 240, height: 320, alignment: Alignment(horizontal: .center, vertical: fact.focus == .top ? .top : .center))
            }
            .overlay {
                LinearGradient(stops: [.init(color: .clear, location: 0.35), .init(color: P.page.opacity(0.7), location: 0.62), .init(color: P.page.opacity(0.97), location: 1)],
                               startPoint: .top, endPoint: .bottom)
            }
            .overlay(alignment: .bottomLeading) {
                VStack(alignment: .leading, spacing: R.spacingSpace4) {
                    Text(fact.tag.uppercased())
                        .font(.custom("BeVietnamPro-SemiBold", fixedSize: 10))
                        .tracking(1.4)
                        .foregroundStyle(P.silverLight)
                        .padding(.horizontal, R.spacingSpace8)
                        .frame(height: 20)
                        .background(.white.opacity(0.12), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.18), lineWidth: R.stroke1Px))
                        .padding(.bottom, R.spacingSpace4)
                    Text(fact.title)
                        .font(.custom("BeVietnamPro-Bold", size: 19, relativeTo: .headline))
                        .tracking(-0.4)
                        .foregroundStyle(M.textWhite)
                    Text(fact.text)
                        .backstageText(.body3)
                        .foregroundStyle(M.textWhite.opacity(0.72))
                        .lineLimit(3, reservesSpace: true)
                }
                .padding(R.spacingSpace16)
            }
            .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
            .overlay(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24).strokeBorder(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom), lineWidth: R.stroke1Px))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(fact.title). \(fact.text)")
    }
}

/// One District benefit: its 3D icon floating over a lit pedestal, then the title and a line, on a
/// silver-edged card. All three cards share one size.
private struct BenefitCard: View {
    let benefit: HPBenefit

    var body: some View {
        HStack(spacing: R.spacingSpace16) {
            ZStack(alignment: .bottom) {
                Ellipse()
                    .fill(RadialGradient(colors: [benefit.glow.opacity(0.6), .clear], center: .center, startRadius: 0, endRadius: 32))
                    .frame(width: 64, height: 14)
                    .offset(y: 4)
                Image(benefit.image)
                    .resizable().scaledToFit()
                    .frame(width: 50, height: 50)
                    .shadow(color: benefit.glow.opacity(0.5), radius: 14, y: 8)
                    .padding(.bottom, R.spacingSpace8)
            }
            .frame(width: 68, height: 68)
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: R.spacingSpace4) {
                Text(benefit.title)
                    .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .headline))
                    .tracking(-0.2)
                    .foregroundStyle(M.textPrimary)
                Text(benefit.detail)
                    .backstageText(.body3)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, R.spacingSpace16)
        .padding(.vertical, R.spacingSpace12)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner20)
                .fill(LinearGradient(colors: [Color(rgba: 0x1E1E22FF), Color(rgba: 0x101012FF)], startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(alignment: .leading) {
                    Ellipse().fill(benefit.glow.opacity(0.2)).frame(width: 150, height: 110).blur(radius: 36).offset(x: -30)
                }
                .overlay {
                    // Brushed-metal sheen across the top.
                    LinearGradient(colors: [.white.opacity(0.06), .clear], startPoint: .top, endPoint: .center)
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner20))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner20)
                .strokeBorder(AngularGradient(colors: [P.silverLight.opacity(0.5), P.silverDeep.opacity(0.2), P.silver.opacity(0.4), P.silverDeep.opacity(0.15), P.silverLight.opacity(0.5)],
                                              center: .center),
                              lineWidth: R.stroke1Px)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A how-to step on a numbered timeline.
private struct StepRow: View {
    let number: Int
    let step: HPStep
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: R.spacingSpace12) {
            VStack(spacing: R.spacingSpace4) {
                Image(systemName: step.icon)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 40, height: 40)
                    .background(M.surfaceSecondary, in: RoundedRectangle(cornerRadius: R.cornerRadiusCorner12))
                if !isLast {
                    Rectangle()
                        .fill(LinearGradient(colors: [.white.opacity(0.2), .white.opacity(0.04)], startPoint: .top, endPoint: .bottom))
                        .frame(width: R.stroke1Px)
                        .frame(maxHeight: .infinity)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("STEP \(number)")
                    .font(.custom("BeVietnamPro-Medium", fixedSize: 10))
                    .tracking(1.2)
                    .foregroundStyle(M.textTertiary)
                Text(step.title).backstageText(.label1).foregroundStyle(M.textPrimary)
                Text(step.text).backstageText(.body3).foregroundStyle(M.textSecondary)
            }
            .padding(.top, 2)
            .padding(.bottom, isLast ? 0 : R.spacingSpace20)
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A collection piece as a showcase card: the product glowing on a spotlit stage, with its name
/// and price inside the card.
private struct SKUCard: View {
    let product: HPProduct
    let number: Int
    let count: Int

    var body: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace0) {
            stage
            VStack(alignment: .leading, spacing: R.spacingSpace12) {
                Text(product.name)
                    .font(.custom("BeVietnamPro-SemiBold", size: 17, relativeTo: .headline))
                    .tracking(-0.3)
                    .foregroundStyle(M.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2, reservesSpace: true)
                VStack(alignment: .leading, spacing: 2) {
                    Text("MRP")
                        .font(.custom("BeVietnamPro-Medium", fixedSize: 9))
                        .tracking(1.2)
                        .foregroundStyle(M.textTertiary)
                    Text(product.price)
                        .font(.custom("BeVietnamPro-Bold", size: 20, relativeTo: .title3))
                        .foregroundStyle(LinearGradient(colors: [.white, P.silver], startPoint: .top, endPoint: .bottom))
                }
            }
            .padding(R.spacingSpace16)
        }
        .frame(width: 280)
        .background {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner24)
                .fill(LinearGradient(colors: [Color(rgba: 0x1C1C20FF), Color(rgba: 0x0D0D0FFF)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) {
                    Ellipse().fill(product.glow.opacity(0.22)).frame(width: 320, height: 220).blur(radius: 60).offset(y: -40)
                }
                .clipShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        }
        .overlay {
            RoundedRectangle(cornerRadius: R.cornerRadiusCorner24)
                .strokeBorder(LinearGradient(colors: [product.glow.opacity(0.45), .white.opacity(0.06), .white.opacity(0.03)], startPoint: .top, endPoint: .bottom),
                              lineWidth: R.stroke1Px)
        }
        .shadow(color: product.glow.opacity(0.12), radius: 24, y: 10)
        .contentShape(RoundedRectangle(cornerRadius: R.cornerRadiusCorner24))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(product.name), \(product.price)")
        .accessibilityHint("Shows details and specs")
    }

    /// The product under a halo, standing on a soft reflection, with its edition tag and position.
    private var stage: some View {
        ZStack {
            Circle()
                .fill(product.glow.opacity(0.4))
                .frame(width: 170, height: 170)
                .blur(radius: 46)
            Ellipse()
                .fill(RadialGradient(colors: [product.glow.opacity(0.45), .clear], center: .center, startRadius: 0, endRadius: 80))
                .frame(width: 170, height: 26)
                .offset(y: 100)
            Image(product.image)
                .resizable().scaledToFit()
                .frame(height: product.kind == .bat ? 212 : 165)
                .rotationEffect(.degrees(product.kind == .bat ? 24 : 0))
                .shadow(color: .black.opacity(0.6), radius: 14, y: 14)
        }
        .frame(height: 250)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .top) {
            HStack {
                if let tag = product.tag {
                    Text(tag)
                        .font(.custom("BeVietnamPro-SemiBold", fixedSize: 9))
                        .tracking(1.4)
                        .foregroundStyle(P.silverLight)
                        .padding(.horizontal, R.spacingSpace8)
                        .frame(height: 22)
                        .background(.white.opacity(0.08), in: Capsule())
                        .overlay(Capsule().strokeBorder(.white.opacity(0.14), lineWidth: R.stroke1Px))
                }
                Spacer()
                Text(String(format: "%02d / %02d", number, count))
                    .font(.custom("BeVietnamPro-Medium", fixedSize: 10))
                    .tracking(1)
                    .foregroundStyle(M.textTertiary)
            }
            .padding(R.spacingSpace16)
        }
        .overlay(alignment: .bottom) {
            LinearGradient(colors: [.white.opacity(0), .white.opacity(0.1), .white.opacity(0)], startPoint: .leading, endPoint: .trailing)
                .frame(height: R.stroke1Px)
        }
    }
}

/// Brushed-silver "Reserve now" pinned to the bottom (Figma's button).
private struct ReserveBar: View {
    var action: () -> Void

    var body: some View {
        VStack(spacing: R.spacingSpace0) {
            LinearGradient(colors: [P.page.opacity(0), P.page], startPoint: .top, endPoint: .bottom)
                .frame(height: 32)
                .allowsHitTesting(false)
            Button(action: action) {
                Text("Reserve now").frame(maxWidth: .infinity)
            }
            .buttonStyle(MetalButtonStyle())
            .accessibilityHint("Jumps to the full collection")
            .padding(.horizontal, R.spacingSpace16)
            .padding(.bottom, R.spacingSpace8)
            .background(P.page)
        }
    }
}

private struct MetalButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.custom("BeVietnamPro-SemiBold", size: 16, relativeTo: .body))
            .foregroundStyle(Color(rgba: 0x111113FF))
            .frame(minHeight: 52)
            .background {
                Capsule().fill(LinearGradient(stops: [.init(color: Color(rgba: 0x8E8E92FF), location: 0), .init(color: Color(rgba: 0xF4F4F5FF), location: 0.35),
                                                      .init(color: Color(rgba: 0xDCDCDFFF), location: 0.7), .init(color: Color(rgba: 0x8A8A8EFF), location: 1)],
                                              startPoint: .leading, endPoint: .trailing))
            }
            .overlay(Capsule().strokeBorder(.white.opacity(0.5), lineWidth: R.stroke1Px))
            .shadow(color: .white.opacity(0.12), radius: 16, y: 4)
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

struct HPFact {
    let image: String
    let tag: String
    let title: String
    let text: String
    /// Where the face sits in the photo, so the card crop keeps it.
    var focus: UnitPoint = .top
}

struct HPBenefit {
    let image: String
    let glow: Color
    let title: String
    let detail: String
}

struct HPStep {
    let icon: String
    let title: String
    let text: String
}

/// Identifies the drop for `readerCover`.
struct HPDropPresentation: Identifiable {
    let id = "sg-hp-10-years"
}

/// Drop content. Products, prices, copy and specs come from the SG × HP inventory sheet; the drop
/// date and store line are placeholders until the launch plan is confirmed.
enum HPDrop {
    // Hardik's 33rd birthday (born 11 Oct 1993). The 11 AM time and store line are placeholders
    // until the launch plan is confirmed with the SG team.
    static let dropDate: Date = {
        var c = DateComponents()
        c.year = 2026; c.month = 10; c.day = 11; c.hour = 11
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")
        return Calendar(identifier: .gregorian).date(from: c) ?? .now
    }()
    static let dropDateShort = "Drops 11 Oct, 11 AM"
    static let dropDateChip = "11 Oct, 11 AM"
    static let dropDateLong = "11th October | 11:00 AM onwards"
    static let stores = "SG stores on District"
    static let storesDetail = "Reserve online, collect in store"

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

    // Public record; worth a final check with the SG team before launch. Photo credits for the
    // `hp_wiki_*` images are in PHOTO_CREDITS.txt.
    static let facts: [HPFact] = [
        HPFact(image: "hp_hardik", tag: "No. 33", title: "Meet Hardik", text: "All-rounder, captain, showman. On 11 October, his jersey number becomes his age."),
        HPFact(image: "hp_wiki_street", tag: "11.10.1993", title: "Born in Surat", text: "His family moved to Baroda when he was young, and his cricket began there."),
        HPFact(image: "hp_wiki_brothers", tag: "Brothers", title: "Pandya and Pandya", text: "Hardik and Krunal came up together, from Baroda to Mumbai Indians."),
        HPFact(image: "hp_wiki_worldcup", tag: "2024", title: "World champion", text: "Bowled the final over of the T20 World Cup final as India won by 7 runs."),
    ]

    static let benefits: [HPBenefit] = [
        HPBenefit(image: "hp_icon_clock", glow: P.silver, title: "Skip the wait", detail: "Walk into the SG store and pick up your piece"),
        HPBenefit(image: "hp_icon_bag", glow: P.willow, title: "Assured pickup", detail: "No delivery delays. Ready when promised"),
        HPBenefit(image: "hp_icon_discount", glow: Color(rgba: 0x6D7CFFFF), title: "No Cost EMI", detail: "Easy instalments on credit card payments"),
    ]

    static let steps: [HPStep] = [
        HPStep(icon: "bag", title: "Pick your piece", text: "Choose from the HP33 drop on the District app"),
        HPStep(icon: "creditcard", title: "Pay on District", text: "Complete your purchase. No Cost EMI available"),
        HPStep(icon: "qrcode.viewfinder", title: "Collect in store", text: "Show your QR code at the SG store and take it home"),
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
