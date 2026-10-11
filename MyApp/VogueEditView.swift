import SwiftUI

private typealias M = BackstageTokens.Mapped
private typealias R = BackstageTokens.Responsive

// District Vogue's Explore tab, "The Edit." (Figma: 1-Nidhi-Workspace › Editorial, 3630:307918).
// A dark editorial scroll under the stage spotlight, read like a magazine: the page snaps section
// by section, and each new section slides up over the last one, which stays pinned beneath it
// like a page on a stack. Headings keep the Figma's mixed
// display styles; every photo card shares one frame (square corners, a hairline border and a
// caption on a scrim tinted from the photo itself).

struct VogueEditView: View {
    @State private var scrollY: CGFloat = 0
    @State private var location = "Golf Course Extension Road"
    /// Where a finished section comes to rest: just under the header.
    @State private var pinTop: CGFloat = 0
    /// Whether the palette page has reached the screen, so the spectrum below it may show.
    @State private var paletteOnScreen = false
    @State private var screenHeight: CGFloat = 0
    @Environment(\.tabBarCompactHandler) private var setTabBarCompact

    private let locations = ["Golf Course Extension Road", "Vatika City", "Cyberhub, DLF Phase 2", "Sector 29"]

    var body: some View {
        ZStack(alignment: .top) {
            M.backgroundPrimary.ignoresSafeArea()
            // Carries the palette page's spectrum on below it to the screen edge. Shown only once that
            // page is on screen, or it would glow through the clear first page at the top.
            PageBackdropView(style: .spectrumFloor)
                .frame(height: 240)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .ignoresSafeArea()
                .opacity(paletteOnScreen ? 1 : 0)
                .animation(.easeInOut(duration: 0.3), value: paletteOnScreen)
            Spotlight(scrollY: scrollY)

            ScrollViewReader { proxy in
            ScrollView(.vertical) {
                // No spacing: each page carries its own margins so its paper covers the gap too.
                VStack(alignment: .leading, spacing: 0) {
                    VogueStoriesSection().stackedPage(pinTop: pinTop, height: pageHeight, backdrop: nil).id(1)
                    VStack(alignment: .leading, spacing: EditLayout.headerGap) {
                        VogueRackSection()
                        VogueBrandTicker()
                    }
                    .stackedPage(pinTop: pinTop, height: pageHeight, backdrop: .windowLight).id(2)
                    VoguePairSection().stackedPage(pinTop: pinTop, height: pageHeight, backdrop: .ruled).id(3)
                    VogueLooksSection().stackedPage(pinTop: pinTop, height: pageHeight, backdrop: .watermark("street")).id(4)
                    VoguePlansSection().stackedPage(pinTop: pinTop, height: pageHeight, backdrop: .grid).id(5)
                    VoguePaletteSection()
                        .padding(.bottom, R.spacingSpace48)
                        .stackedPage(pinTop: pinTop, height: pageHeight, backdrop: .spectrum)
                        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { top in
                            paletteOnScreen = screenHeight > 0 && top < screenHeight
                        }
                        .id(6)
                }
                .scrollTargetLayout()
            }
            // Pages, not a feed: a flick settles on the next section's top edge.
            .scrollTargetBehavior(.viewAligned)
            #if DEBUG
            // Debug builds accept `-startSection N` so a simulator can open on a given section.
            .task {
                let args = ProcessInfo.processInfo.arguments
                if let i = args.firstIndex(of: "-startSection"), i + 1 < args.count, let n = Int(args[i + 1]) {
                    try? await Task.sleep(for: .seconds(2.5))
                    proxy.scrollTo(n, anchor: .topLeading)
                }
            }
            #endif
            .scrollIndicators(.hidden)
            .safeAreaInset(edge: .top, spacing: 0) {
                VogueEditHeader(location: $location, locations: locations, scrolled: scrollY < -8)
                    .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { pinTop = $0 }
            }
            .modifier(ExploreScrollTracker(onScroll: scrolled(to:)))
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).maxY } action: { screenHeight = $0 }
        .environment(\.editorialStyle, .newspaper)
    }

    /// Every page fills the screen below the header, so each section reads as one full page.
    private var pageHeight: CGFloat { max(0, screenHeight - pinTop) }

    /// `y` is the content's top edge: 0 at rest, negative as the page scrolls down.
    private func scrolled(to y: CGFloat) {
        let delta = y - scrollY
        if y > -40 { setTabBarCompact(false) }
        else if delta < -6 { setTabBarCompact(true) }
        else if delta > 6 { setTabBarCompact(false) }
        scrollY = y
    }
}

// MARK: - System

/// The page's two voices: Playfair Display for headlines and card titles, Figtree for everything
/// you read at a glance (deks, kickers, prices, labels).
enum EditType {
    static func display(_ size: CGFloat, italic: Bool = false, relativeTo style: Font.TextStyle = .title) -> Font {
        .custom(italic ? "PlayfairDisplayItalic-SemiBold" : "PlayfairDisplayRoman-SemiBold", size: size, relativeTo: style)
    }

    static func sans(_ size: CGFloat, _ weight: SansWeight = .regular, relativeTo style: Font.TextStyle = .body) -> Font {
        .custom("Figtree-\(weight.rawValue)", size: size, relativeTo: style)
    }

    enum SansWeight: String { case light = "Light", regular = "Regular", medium = "Medium", semibold = "SemiBold" }
}

/// One rhythm for the whole page.
enum EditLayout {
    static let gutter = R.spacingSpace16
    static let sectionGap = R.spacingSpace56
    /// Space between the header and the first line of every page.
    static let pageTop = R.spacingSpace56
    /// Space below the content on every page.
    static let pageMargin = R.spacingSpace40
    static let headerGap = R.spacingSpace24
    static let cardGap = R.spacingSpace12
}

/// The section openers: a folio-numbered serif for most, and the Figma's stacked two-liner for
/// the plans.
private enum EditHeading {
    /// Ghosted folio number behind a 32pt headline, with a dek ("Hot off the rack", "Style your
    /// Staples", "Cop these Looks", "Pick your Palette").
    case folio(Int, Text, dek: String)
    /// Two 36pt lines set tight, the second in italic ("Fits for / Every Plan").
    case stacked(String, String, dek: String)
}

private struct EditSectionHeader: View {
    let style: EditHeading

    var body: some View {
        content
            .foregroundStyle(M.textWhite)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, EditLayout.gutter)
    }

    @ViewBuilder private var content: some View {
        switch style {
        case let .folio(number, title, dek):
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VStack(alignment: .leading, spacing: -28) {
                    Text(String(format: "%02d", number))
                        .font(EditType.display(60))
                        .foregroundStyle(LinearGradient(stops: [.init(color: M.textWhite, location: 0.33), .init(color: Color(hex: 0x262626), location: 1)],
                                                        startPoint: .top, endPoint: .bottom))
                        .opacity(0.2)
                        // Trims the face's tall line box so the folio starts level with the
                        // other pages' headings.
                        .padding(.top, -20)
                        .accessibilityHidden(true)
                    title.font(EditType.display(32)).accessibilityAddTraits(.isHeader)
                }
                EditDek(text: dek)
            }
        case let .stacked(first, second, dek):
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VStack(alignment: .leading, spacing: -20) {
                    Text(first).font(EditType.display(36))
                    Text(second).font(EditType.display(36, italic: true))
                }
                .accessibilityElement(children: .combine)
                .accessibilityAddTraits(.isHeader)
                EditDek(text: dek)
            }
        }
    }
}

/// Light Figtree standfirst under a heading.
private struct EditDek: View {
    let text: String

    var body: some View {
        Text(text)
            .font(EditType.sans(14, .light, relativeTo: .subheadline))
            .tracking(0.28)
            .foregroundStyle(M.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// Position in a carousel: a numeric counter, then the design's long arrow as a gauge whose
/// bright run grows as you swipe.
private struct EditProgress: View {
    let index: Int
    let count: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let progress = count > 0 ? CGFloat(index + 1) / CGFloat(count) : 1
        HStack(spacing: R.spacingSpace12) {
            Text("\(String(format: "%02d", index + 1)) / \(String(format: "%02d", count))")
                .font(EditType.sans(11, .medium, relativeTo: .caption))
                .tracking(1)
                .monospacedDigit()
                .foregroundStyle(M.textSecondary)
                .contentTransition(.numericText(value: Double(index)))
            HStack(spacing: 0) {
                GeometryReader { g in
                    ZStack(alignment: .leading) {
                        Rectangle().fill(M.borderIntense).frame(height: R.stroke1Px)
                        Rectangle().fill(M.textWhite).frame(width: g.size.width * progress, height: R.stroke2Px)
                    }
                    .frame(maxHeight: .infinity)
                }
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .regular))
                    .foregroundStyle(M.textWhite)
                    .padding(.leading, -5)
            }
        }
        .frame(height: 22)
        .padding(.horizontal, EditLayout.gutter)
        .animation(reduceMotion ? nil : .smooth, value: index)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index + 1) of \(count)")
    }
}

// MARK: - Page stack

private extension View {
    /// One magazine page. Once its top reaches the header it stays put, and the next page slides
    /// up over it; the covered page sinks back (a little smaller, a little darker) until hidden.
    /// `height` is the page's minimum height (one screen); `backdrop` is the page's paper; nil
    /// leaves it clear so the spotlight shows through.
    func stackedPage(pinTop: CGFloat, height: CGFloat, backdrop: PageBackdrop?) -> some View {
        modifier(StackedPage(pinTop: pinTop, height: height, backdrop: backdrop))
    }
}

private struct StackedPage: ViewModifier {
    let pinTop: CGFloat
    let height: CGFloat
    let backdrop: PageBackdrop?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        let pin = pinTop
        let sink: CGFloat = reduceMotion ? 0 : 0.05
        return content
            // Content keeps its natural height (carousels would otherwise stretch to fill the page).
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, EditLayout.pageTop)
            .padding(.bottom, EditLayout.pageMargin)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
            .background {
                if let backdrop {
                    PageBackdropView(style: backdrop)
                        .shadow(color: .black.opacity(0.6), radius: 18, y: -8)
                        .overlay(alignment: .top) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                }
            }
            .visualEffect { view, proxy in
                let frame = proxy.frame(in: .global)
                // How far the page has been pushed past its resting line.
                let past = max(0, pin - frame.minY)
                let covered = min(1, past / max(1, frame.height))
                return view
                    .offset(y: past)
                    .scaleEffect(1 - sink * covered, anchor: .top)
                    .brightness(-0.3 * covered)
                    .opacity(covered >= 1 ? 0 : 1)
            }
    }
}

/// Each page's paper. All sit on the same near-black so the stack reads as one issue; each adds
/// one quiet print detail that suits its section. Colours here are decorative, not UI chrome.
enum PageBackdrop {
    /// Warm light falling in from the top corner, like a shop window (the rack).
    case windowLight
    /// Faint notebook rules and a margin line, like a stylist's guide (pairings).
    case ruled
    /// An oversized italic word set ghost-faint behind the page (street looks).
    case watermark(String)
    /// A printer's dot grid under a cool slate wash (plans).
    case grid
    /// The Figma's rainbow, rising softly from the foot of the page (palettes).
    case spectrum
    /// The spectrum at full strength, for the strip below the last page.
    case spectrumFloor
}

private struct PageBackdropView: View {
    let style: PageBackdrop

    static let spectrum = LinearGradient(colors: [0x58E487, 0xEBDF6F, 0xF09275, 0xBCAEFE, 0xFFD7DF, 0x45A4F7, 0x00BDA4].map { Color(hex: $0) },
                                         startPoint: .leading, endPoint: .trailing)

    var body: some View {
        ZStack {
            M.backgroundPrimary
            detail
        }
        .clipped()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder private var detail: some View {
        switch style {
        case .windowLight:
            RadialGradient(colors: [Color(hex: 0xE5AC48).opacity(0.11), Color(hex: 0xE5AC48).opacity(0)],
                           center: .topTrailing, startRadius: 0, endRadius: 460)
        case .ruled:
            Canvas { context, size in
                var rules = Path()
                var y: CGFloat = 32
                while y < size.height {
                    rules.move(to: CGPoint(x: 0, y: y))
                    rules.addLine(to: CGPoint(x: size.width, y: y))
                    y += 32
                }
                context.stroke(rules, with: .color(.white.opacity(0.035)), lineWidth: 1)
                var margin = Path()
                margin.move(to: CGPoint(x: 8, y: 0))
                margin.addLine(to: CGPoint(x: 8, y: size.height))
                context.stroke(margin, with: .color(Color(hex: 0xC8402F).opacity(0.22)), lineWidth: 1)
            }
        case let .watermark(word):
            Text(word)
                .font(EditType.display(230, italic: true))
                .foregroundStyle(.white.opacity(0.035))
                .fixedSize()
                .rotationEffect(.degrees(-8))
                .offset(x: 70, y: 150)
        case .grid:
            ZStack {
                LinearGradient(colors: [Color(hex: 0x2F3E4E).opacity(0.35), Color(hex: 0x2F3E4E).opacity(0)],
                               startPoint: .top, endPoint: .bottom)
                Canvas { context, size in
                    var dots = Path()
                    let step: CGFloat = 18
                    var y = step / 2
                    while y < size.height {
                        var x = step / 2
                        while x < size.width {
                            dots.addEllipse(in: CGRect(x: x - 0.7, y: y - 0.7, width: 1.4, height: 1.4))
                            x += step
                        }
                        y += step
                    }
                    context.fill(dots, with: .color(.white.opacity(0.07)))
                }
            }
        case .spectrum:
            Self.spectrum
                .opacity(0.09)
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .center, endPoint: .bottom))
        case .spectrumFloor:
            Self.spectrum.opacity(0.09)
        }
    }
}

/// Small tracked uppercase line above a card title.
private struct VogueKicker: View {
    let text: String
    var rule = false

    var body: some View {
        HStack(spacing: 7.6) {
            if rule {
                Rectangle().fill(M.textWhite.opacity(0.6)).frame(width: 22.8, height: R.stroke1Px)
            }
            Text(text.uppercased())
                .font(EditType.sans(11, .medium, relativeTo: .caption2))
                .tracking(2.2)
                .foregroundStyle(M.textWhite.opacity(0.6))
                .lineLimit(1)
        }
    }
}

/// The shared photo card: art, a scrim tinted from the photo, a hairline frame and a caption.
private struct VoguePhotoCard<Caption: View>: View {
    let art: Art
    let width: CGFloat
    let height: CGFloat
    /// How far up the card the scrim reaches (0…1).
    var scrimReach: CGFloat = 0.55
    @ViewBuilder let caption: () -> Caption

    var body: some View {
        let tint = DominantColor.of(art)
        ArtView(art: art)
            .frame(width: width, height: height)
            .overlay {
                // A black legibility scrim, warmed by the photo's own colour.
                ZStack {
                    LinearGradient(stops: [.init(color: .clear, location: 1 - scrimReach), .init(color: .black.opacity(0.85), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                    LinearGradient(stops: [.init(color: .clear, location: 1 - scrimReach), .init(color: tint.opacity(0.4), location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                }
                .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomLeading) {
                caption()
                    .padding(R.spacingSpace12 + 3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay { Rectangle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
            .clipShape(Rectangle())
            .contentShape(Rectangle())
    }
}

// MARK: - Header

/// Back to District, the page name with its location, and the profile. Frosts once the page moves.
private struct VogueEditHeader: View {
    @Binding var location: String
    let locations: [String]
    let scrolled: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    var body: some View {
        HStack(spacing: R.spacingSpace12) {
            GlassIconButton(systemName: "arrow.left", label: "Back to District")

            Menu {
                Picker("Location", selection: $location) {
                    ForEach(locations, id: \.self) { Text($0).tag($0) }
                }
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Editorial")
                        .font(EditType.sans(16, .semibold, relativeTo: .headline))
                        .foregroundStyle(M.textPrimary)
                    HStack(spacing: 4) {
                        Text(location).lineLimit(1)
                        Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold))
                    }
                    .font(EditType.sans(12, relativeTo: .caption))
                    .foregroundStyle(M.textSecondary)
                    .id(location)
                    .transition(.asymmetric(insertion: .move(edge: .bottom), removal: .move(edge: .top)).combined(with: .opacity))
                }
                .clipped()
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .accessibilityLabel("Editorial, location \(location)")
            .accessibilityHint("Changes location")

            Spacer(minLength: 0)

            Button {} label: {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 30))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(M.iconPrimary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Profile")
        }
        .padding(.horizontal, EditLayout.gutter)
        .padding(.vertical, R.spacingSpace8)
        .background {
            if scrolled {
                Group {
                    if reduceTransparency { M.backgroundPrimary } else {
                        ZStack { Rectangle().fill(.ultraThinMaterial); M.backgroundPrimary.opacity(0.55) }
                    }
                }
                .overlay(alignment: .bottom) { Rectangle().fill(M.borderSubtle).frame(height: R.stroke1Px) }
                .ignoresSafeArea(edges: .top)
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: scrolled)
        .animation(.easeInOut(duration: 0.3), value: location)
        .dynamicTypeSize(...DynamicTypeSize.accessibility2)
    }
}

// MARK: - 01 The Edit (stories)

private struct VogueStoriesSection: View {
    @State private var reading: Story?
    @Namespace private var zoom

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            masthead
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(EditorialData.stories) { story in
                        Button { reading = story } label: { card(story) }
                            .buttonStyle(PressableStyle())
                            .zoomSource(id: story.id, in: zoom)
                            .accessibilityLabel("\(story.brand): \(story.title)")
                            .accessibilityHint("Opens the story")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
        }
        .readerCover(item: $reading) { story in
            StoryReaderView(story: story).zoomTransition(id: story.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: reading?.id)
    }

    /// The page nameplate: "The Edit." over a double rule.
    private var masthead: some View {
        VStack(alignment: .leading, spacing: R.spacingSpace16) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                Text("The Edit.")
                    .font(EditType.display(44, relativeTo: .largeTitle))
                    .foregroundStyle(M.textWhite)
                    .accessibilityAddTraits(.isHeader)
                Text("Five homegrown labels, the hands behind them, and the shops in your district where you can see the work up close.")
                    .font(EditType.sans(14, .light, relativeTo: .subheadline))
                    .tracking(0.28)
                    .foregroundStyle(M.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            VStack(spacing: 2) {
                Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
                Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px)
            }
            .accessibilityHidden(true)
        }
        .padding(.horizontal, EditLayout.gutter)
    }

    private func card(_ story: Story) -> some View {
        VoguePhotoCard(art: story.art, width: 300, height: 400, scrimReach: 0.62) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VogueKicker(text: story.brand, rule: true)
                Text(story.title)
                    .font(EditType.display(22, relativeTo: .title2))
                    .tracking(-0.22)
                    .lineSpacing(2)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
                Text(story.article.dek)
                    .font(EditType.sans(13, relativeTo: .footnote))
                    .foregroundStyle(M.textWhite.opacity(0.6))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
        }
    }
}

// MARK: - 02 Hot off the rack

private struct VogueRackSection: View {
    @State private var opened: Product?
    @State private var index = 0

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(style: .folio(2, Text("Hot off the rack"),
                                            dek: "Fresh in this week from the labels on your high street, and the stores that stock them."))
            VStack(alignment: .leading, spacing: R.spacingSpace16) {
                RackCarousel(products: EditorialData.products, index: $index) { opened = $0 }
                EditProgress(index: index, count: EditorialData.products.count)
            }
        }
        .readerCover(item: $opened) { ProductDetailView(product: $0) }
        .sensoryFeedback(.selection, trigger: index)
    }
}

/// An endless shop window: the card in front stands tall and the rest wait smaller. A native
/// paging scroll view lies invisibly over the cards and drives them, so swiping hands the height
/// to the next card (while the one before steps down and slides away) with real scroll physics.
/// The scroll view is many laps long and starts in the middle, so the line never runs out.
private struct RackCarousel: View {
    let products: [Product]
    /// The focused product (wrapped into `products`).
    @Binding var index: Int
    let open: (Product) -> Void

    @State private var page: Int?
    /// The pager's horizontal content offset.
    @State private var offset: CGFloat = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let laps = 400
    private let large = CGSize(width: 256, height: 338)
    private let small = CGSize(width: 204, height: 270)
    private let gap = EditLayout.cardGap
    private var step: CGFloat { large.width + gap }

    var body: some View {
        // Fractional position: 0.5 is halfway to the next card.
        let p = offset / step
        let first = Int(floor(p)) - 1
        let focused = Int(p.rounded())

        ZStack(alignment: .topLeading) {
            ForEach(first...(first + 4), id: \.self) { k in
                let r = CGFloat(k) - p
                let t = min(1, abs(r))
                let product = products[wrap(k)]
                card(product, size: size(t), emphasis: 1 - t)
                    .offset(x: x(r))
                    .opacity(r < -0.98 ? 0 : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityHidden(k != focused)
                    .accessibilityLabel("\(product.name) by \(product.brand), \(product.price) onwards")
                    .accessibilityHint("Double-tap to open. Swipe up or down for the next piece.")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction { open(product) }
                    .accessibilityAdjustableAction { direction in
                        switch direction {
                        case .increment: scroll(to: focused + 1)
                        case .decrement: scroll(to: focused - 1)
                        @unknown default: break
                        }
                    }
            }
        }
        .frame(height: large.height, alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.leading, EditLayout.gutter)
        .overlay { pager(focused: focused, p: p) }
        .onChange(of: page) { index = wrap(page ?? 0) }
    }

    /// The invisible scroll surface. Its pages are one card-step wide and snap like the cards.
    private func pager(focused: Int, p: CGFloat) -> some View {
        ScrollView(.horizontal) {
            LazyHStack(spacing: 0) {
                ForEach(0..<(products.count * laps), id: \.self) { _ in
                    // Clear views don't take touches, so give each page a shape to catch the swipe.
                    Color.clear
                        .frame(width: step, height: large.height)
                        .contentShape(Rectangle())
                }
            }
            .scrollTargetLayout()
            .background {
                GeometryReader { g in
                    Color.clear.preference(key: RackOffsetKey.self, value: -g.frame(in: .named("rackPager")).minX)
                }
            }
        }
        .coordinateSpace(name: "rackPager")
        .scrollIndicators(.hidden)
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $page, anchor: .leading)
        // iOS 18+: read the offset from the scroll view itself; the preference is the iOS 17 path
        // (on newer systems it can stop reporting once laid out).
        .modifier(RackOffsetTracker { offset = $0 })
        .onPreferenceChange(RackOffsetKey.self) { x in
            if #available(iOS 18.0, macOS 15.0, *) { return }
            offset = x
        }
        .onAppear { if page == nil { page = products.count * laps / 2 } }
        .contentShape(Rectangle())
        .onTapGesture { location in tap(at: location, focused: focused, p: p) }
        .accessibilityHidden(true)
    }

    /// Opens the card in front; tapping a waiting card brings it forward instead.
    private func tap(at location: CGPoint, focused: Int, p: CGFloat) {
        let x = location.x - EditLayout.gutter
        for k in (Int(floor(p)) - 1)...(Int(floor(p)) + 3) {
            let r = CGFloat(k) - p
            let s = size(min(1, abs(r)))
            let left = self.x(r)
            guard x >= left, x <= left + s.width, location.y <= s.height else { continue }
            if k == focused { open(products[wrap(k)]) } else { scroll(to: k) }
            return
        }
    }

    private func scroll(to k: Int) {
        withAnimation(reduceMotion ? .easeOut(duration: 0.2) : .spring(response: 0.5, dampingFraction: 0.86)) { page = k }
    }

    private func size(_ t: CGFloat) -> CGSize {
        CGSize(width: lerp(large.width, small.width, t), height: lerp(large.height, small.height, t))
    }

    /// Leading edge of a card `r` places from the focused slot (negative is already passed).
    private func x(_ r: CGFloat) -> CGFloat {
        if r <= 0 { return r * (small.width + gap) }
        if r <= 1 { return r * step }
        return step + (r - 1) * (small.width + gap)
    }

    private func wrap(_ k: Int) -> Int { ((k % products.count) + products.count) % products.count }
    private func lerp(_ a: CGFloat, _ b: CGFloat, _ t: CGFloat) -> CGFloat { a + (b - a) * t }

    private func card(_ product: Product, size: CGSize, emphasis: CGFloat) -> some View {
        VoguePhotoCard(art: product.art, width: size.width, height: size.height, scrimReach: 0.32) {
            VStack(alignment: .leading, spacing: 4) {
                Text(product.brand.uppercased())
                    .font(EditType.sans(11, .light, relativeTo: .caption))
                    .tracking(0.24)
                    .foregroundStyle(M.textWhite.opacity(0.75))
                Text(product.name)
                    .font(EditType.display(16, relativeTo: .headline))
                    .tracking(-0.24)
                    .foregroundStyle(M.textWhite)
                    .lineLimit(1)
                Text("\(product.price) onwards")
                    .font(EditType.sans(11, relativeTo: .caption))
                    .tracking(0.22)
                    .foregroundStyle(M.textPrimary)
            }
        }
        // The waiting cards sit back a touch so the tall one reads as "in front".
        .brightness(-0.12 * (1 - emphasis))
    }
}

private struct RackOffsetTracker: ViewModifier {
    let onScroll: (CGFloat) -> Void

    func body(content: Content) -> some View {
        if #available(iOS 18.0, macOS 15.0, *) {
            content.onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.x + $0.contentInsets.leading } action: { _, x in
                onScroll(x)
            }
        } else {
            content
        }
    }
}

private struct RackOffsetKey: PreferenceKey {
    static let defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

/// Full-bleed tape of the labels in this edit, between hairlines.
private struct VogueBrandTicker: View {
    private var brands: [String] {
        var seen = Set<String>()
        return (EditorialData.stories.map(\.brand) + EditorialData.products.map(\.brand))
            .filter { seen.insert($0.lowercased()).inserted }
    }

    var body: some View {
        // The tape lives in an overlay so its endless width never widens the page.
        Color.clear.overlay(alignment: .leading) {
          Marquee(speed: 24) {
            HStack(spacing: R.spacingSpace12) {
                ForEach(brands, id: \.self) { brand in
                    Text(brand.uppercased())
                    Image(systemName: "sparkle").font(.system(size: 6))
                }
            }
            .font(EditType.sans(10, relativeTo: .caption2))
            .tracking(1.2)
            .foregroundStyle(M.textSecondary)
            .padding(.trailing, R.spacingSpace12)
          }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 28)
        .background(M.surfaceTransparent)
        .overlay(alignment: .top) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
        .overlay(alignment: .bottom) { Rectangle().fill(M.borderModerate).frame(height: R.stroke1Px) }
        .clipped()
    }
}

// MARK: - 03 Style your staples

private struct VoguePairSection: View {
    @State private var opened: Opened?

    struct Opened: Identifiable { let id: String; let staple: Staple }

    /// The cut-out each staple is photographed as, with the staple it opens.
    private var rows: [(staple: Staple, cutout: String)] {
        let byTitle = Dictionary(uniqueKeysWithValues: EditorialData.staples.map { ($0.title, $0) })
        var rows: [(Staple, String)] = []
        if let s = byTitle["Straight denim"] { rows.append((s, "vogue_pair_jeans")) }
        if let s = byTitle["White tee"] { rows.append((s, "vogue_pair_tee")) }
        if let blazer = byTitle["Sharp blazer"] {
            // Tailored shorts borrow the blazer's lookbook: the same sharp, after-office styling.
            let shorts = Staple(title: "Tailored black shorts", subtitle: blazer.subtitle, thumb: blazer.thumb,
                                pairs: blazer.pairs, looks: blazer.looks)
            rows.append((shorts, "vogue_pair_shorts"))
        }
        return rows
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(style: .folio(3, Text("Style your \(Text("Staples").font(EditType.display(32, italic: true)))"),
                                            dek: "The pieces you already own, styled every way they go. Pick one and swipe through its looks."))
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(rows, id: \.staple.id) { row in
                        Button { opened = Opened(id: row.staple.id, staple: row.staple) } label: {
                            PairCard(staple: row.staple, cutout: row.cutout)
                        }
                        .buttonStyle(PressableStyle())
                        .accessibilityLabel("\(row.staple.looks.count) ways to style your \(row.staple.title.lowercased())")
                        .accessibilityHint("Opens the lookbook")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
        }
        .readerCover(item: $opened) { StapleLookbookView(staple: $0.staple, start: 0) }
    }
}

/// "This" is the staple, shown as a pinned cut-out; "that" is a full look built on it, filling the
/// card behind. Same frame and caption as every other card on the page.
private struct PairCard: View {
    let staple: Staple
    let cutout: String

    var body: some View {
        VoguePhotoCard(art: staple.looks.first ?? staple.thumb, width: 301, height: 391, scrimReach: 0.5) {
            VStack(alignment: .leading, spacing: R.spacingSpace8) {
                VogueKicker(text: "District style guide", rule: true)
                Text("\(staple.looks.count) ways to style your \(staple.title.lowercased())")
                    .font(EditType.display(20, relativeTo: .title3))
                    .lineSpacing(2)
                    .foregroundStyle(M.textWhite)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                Text("With \(staple.pairs.prefix(2).map { $0.name.lowercased() }.joined(separator: ", ")) and more")
                    .font(EditType.sans(13, relativeTo: .footnote))
                    .foregroundStyle(M.textWhite.opacity(0.6))
                    .lineLimit(1)
            }
        }
        .overlay(alignment: .topLeading) { swatch.padding(R.spacingSpace12 + 3) }
    }

    /// The staple on white, pinned to the look with a "+".
    private var swatch: some View {
        Image(cutout)
            .resizable()
            .scaledToFill()
            .frame(width: 84, height: 112)
            .background(M.textWhite)
            .clipped()
            .overlay { Rectangle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
            .shadow(color: .black.opacity(0.35), radius: 10, y: 4)
            .overlay(alignment: .bottomTrailing) {
                Image(systemName: "plus")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(M.textInverse)
                    .frame(width: 24, height: 24)
                    .background(M.surfaceInverse, in: Circle())
                    .offset(x: 10, y: 10)
            }
            .accessibilityHidden(true)
    }
}

// MARK: - 04 Cop these looks

private struct VogueLooksSection: View {
    /// Street-style looks from the Figma shoot, each tagged with what she's wearing.
    static let looks: [Look] = [
        Look(title: "The Olive Utility", art: Art("vogue_look_olive", [0x4A5A2A, 0x8A9A5A, 0x9FB6C9], seed: 801), spots: [
            Hotspot(x: 0.62, y: 0.4, item: "Olive utility jacket", price: "₹4,990"),
            Hotspot(x: 0.27, y: 0.37, item: "Mini box bag", price: "₹2,950"),
            Hotspot(x: 0.48, y: 0.76, item: "Light-wash mom jeans", price: "₹2,450"),
        ]),
        Look(title: "The Ivory Suit", art: Art("vogue_look_ivory", [0xE9E2D4, 0xC9B79A, 0x5A5F66], seed: 803), spots: [
            Hotspot(x: 0.6, y: 0.38, item: "Cream tailored blazer", price: "₹5,490"),
            Hotspot(x: 0.3, y: 0.36, item: "Mini box bag", price: "₹2,950"),
            Hotspot(x: 0.52, y: 0.74, item: "Ivory wide-leg trousers", price: "₹3,290"),
        ]),
        Look(title: "The Navy Overcoat", art: Art("vogue_look_navy", [0x1A2238, 0x2F3E4E, 0xC9B79A], seed: 805), spots: [
            Hotspot(x: 0.64, y: 0.5, item: "Navy double-breasted coat", price: "₹8,990"),
            Hotspot(x: 0.5, y: 0.36, item: "Cable-knit vest", price: "₹2,890"),
            Hotspot(x: 0.5, y: 0.8, item: "Charcoal straight trousers", price: "₹3,490"),
        ]),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(style: .folio(4, Text("Cop these \(Text("Looks").font(EditType.display(32, italic: true)))"),
                                            dek: "Three outfits spotted on the street. Tap a dot to shop the exact piece, or something close to it."))
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(Self.looks) { VogueLookCard(look: $0) }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
        }
    }
}

private struct VogueLookCard: View {
    let look: Look
    @State private var shopping: Shopping?

    struct Shopping: Identifiable { let id: Int }

    var body: some View {
        VoguePhotoCard(art: look.art, width: 301, height: 391, scrimReach: 0.3) {
            HStack(alignment: .lastTextBaseline) {
                Text(look.title)
                    .font(EditType.sans(16, .semibold, relativeTo: .headline))
                    .tracking(0.32)
                    .foregroundStyle(M.textPrimary)
                Spacer(minLength: R.spacingSpace8)
                Text("\(look.spots.count) pieces")
                    .font(EditType.sans(11, relativeTo: .caption))
                    .tracking(1)
                    .foregroundStyle(M.textWhite.opacity(0.6))
            }
        }
        .overlay {
            GeometryReader { geo in
                ForEach(Array(look.spots.enumerated()), id: \.element.id) { i, spot in
                    HotspotPin(spot: spot, isActive: shopping?.id == i) { shopping = Shopping(id: i) }
                        .position(x: spot.x * geo.size.width, y: spot.y * geo.size.height)
                }
            }
        }
        .dynamicTypeSize(...DynamicTypeSize.accessibility1)
        .sensoryFeedback(.impact(weight: .light), trigger: shopping?.id)
        .sheet(item: $shopping) { ShopTheLookView(look: look, start: $0.id) }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(look.title)
    }
}

// MARK: - 05 Fits for every plan

private struct VoguePlansSection: View {
    @State private var opened: Plan?
    @State private var visible: String?
    @Namespace private var zoom

    /// Cover photo per occasion; the gallery behind each is the plan's own collection.
    private var covers: [(plan: Plan, cover: Art)] {
        let pairs: [(String, String)] = [
            ("Office to after-hours", "vogue_fit_office"), ("Activewear", "vogue_fit_active"),
            ("Sunday brunch", "vogue_fit_brunch"), ("Diwali parties", "vogue_fit_festive"),
        ]
        return pairs.compactMap { title, image in
            guard let plan = EditorialData.plans.first(where: { $0.title == title }) else { return nil }
            return (plan, Art(image, plan.cards.first?.hexes ?? [0x333333, 0x666666], seed: 820))
        }
    }

    var body: some View {
        let covers = covers
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(style: .stacked("Fits for", "Every Plan",
                                              dek: "A desk day, a gym run, a long brunch, a festive night: an edit for each, picked from the labels in your district."))
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(covers, id: \.plan.id) { item in
                        Button { opened = item.plan } label: { PlanCard(plan: item.plan, cover: item.cover) }
                            .buttonStyle(PressableStyle())
                            .zoomSource(id: item.plan.id, in: zoom)
                            .id(item.plan.id)
                            .accessibilityLabel("\(item.plan.title), \(item.plan.count) looks")
                            .accessibilityHint("Opens the plan's looks")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
            .scrollPosition(id: $visible, anchor: .leading)

            EditProgress(index: covers.firstIndex { $0.plan.id == visible } ?? 0, count: covers.count)
        }
        .readerCover(item: $opened) { plan in
            PlanGalleryView(plan: plan).zoomTransition(id: plan.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }
}

/// One plan: the cover photo with its name set at the top, over a strip of three looks from the
/// plan's collection.
private struct PlanCard: View {
    let plan: Plan
    let cover: Art

    static let width: CGFloat = 290
    static let coverHeight: CGFloat = 300
    static let stripHeight: CGFloat = 100
    static let gap: CGFloat = 3

    /// The first three looks that aren't the cover itself.
    private var strip: [Art] {
        Array(plan.gallery.filter { $0.image != cover.image }.prefix(3))
    }

    var body: some View {
        VStack(spacing: Self.gap) {
            ArtView(art: cover)
                .frame(width: Self.width, height: Self.coverHeight)
                .clipped()
                .overlay(alignment: .top) {
                    LinearGradient(stops: [.init(color: .black.opacity(0.75), location: 0), .init(color: .clear, location: 1)],
                                   startPoint: .top, endPoint: .bottom)
                        .frame(height: 140)
                        .allowsHitTesting(false)
                }
                .overlay(alignment: .topLeading) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(plan.title)
                            .font(EditType.display(24, relativeTo: .title2))
                            .tracking(-0.24)
                            .foregroundStyle(M.textWhite)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        Text("\(plan.count) looks")
                            .font(EditType.sans(13, relativeTo: .footnote))
                            .foregroundStyle(M.textWhite.opacity(0.6))
                    }
                    .padding(R.spacingSpace16)
                }
            HStack(spacing: Self.gap) {
                ForEach(strip, id: \.self) { look in
                    ArtView(art: look)
                        .frame(width: (Self.width - 2 * Self.gap) / 3, height: Self.stripHeight)
                        .clipped()
                }
            }
            .frame(width: Self.width, alignment: .leading)
        }
        .overlay { Rectangle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
        .clipShape(Rectangle())
        .contentShape(Rectangle())
    }
}

// MARK: - 06 Pick your palette

private struct VoguePaletteSection: View {
    @State private var opened: Palette?
    @Namespace private var zoom

    /// "Palette", one letter per shade from the design.
    private var title: Text {
        let shades: [UInt32] = [0x58E487, 0xEBDF6F, 0xF09275, 0xBCAEFE, 0xFFD7DF, 0x45A4F7, 0x00BDA4]
        let word = Array("Palette").enumerated().reduce(Text("")) { text, letter in
            Text("\(text)\(Text(String(letter.element)).foregroundStyle(Color(hex: shades[letter.offset % shades.count])))")
        }
        return Text("Pick your \(word.font(EditType.display(32, italic: true)))")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EditLayout.headerGap) {
            EditSectionHeader(style: .folio(6, title, dek: "Start from a colour story and build the outfit around it."))
            ScrollView(.horizontal) {
                LazyHStack(spacing: EditLayout.cardGap) {
                    ForEach(EditorialData.palettes) { palette in
                        Button { opened = palette } label: {
                            VStack(spacing: 0) {
                                VoguePhotoCard(art: palette.looks[0], width: 290, height: 384, scrimReach: 0.3) {
                                    HStack(alignment: .lastTextBaseline) {
                                        Text(palette.name)
                                            .font(EditType.display(20, relativeTo: .title3))
                                            .tracking(-0.24)
                                            .foregroundStyle(M.textWhite)
                                        Spacer(minLength: R.spacingSpace8)
                                        Text("\(palette.lookCount) looks")
                                            .font(EditType.sans(11, .medium, relativeTo: .caption))
                                            .tracking(1)
                                            .foregroundStyle(M.textWhite.opacity(0.7))
                                    }
                                }
                                strips(palette)
                            }
                        }
                        .buttonStyle(PressableStyle())
                        .zoomSource(id: palette.id, in: zoom)
                        .accessibilityLabel("\(palette.name), \(palette.lookCount) looks: \(palette.shades.joined(separator: ", "))")
                    }
                }
                .scrollTargetLayout()
            }
            .carousel()
            .defaultScrollAnchor(.leading)
        }
        .readerCover(item: $opened) { palette in
            PaletteDetailView(palette: palette).zoomTransition(id: palette.id, in: zoom)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: opened?.id)
    }

    /// The palette as paint chips under the photo: one band per shade, each named.
    private func strips(_ palette: Palette) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(zip(palette.hexes, palette.shades).enumerated()), id: \.offset) { _, shade in
                Color(hex: shade.0)
                    .overlay(alignment: .bottomLeading) {
                        Text(shade.1.uppercased())
                            .font(EditType.sans(8, .semibold, relativeTo: .caption2))
                            .tracking(0.8)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .foregroundStyle(Self.isLight(shade.0) ? Color.black.opacity(0.6) : Color.white.opacity(0.75))
                            .padding(.horizontal, 6)
                            .padding(.bottom, 6)
                    }
            }
        }
        .frame(width: 290, height: 40)
        .overlay { Rectangle().strokeBorder(M.borderSubtle, lineWidth: R.stroke1Px) }
        .accessibilityHidden(true)
    }

    /// Whether a shade needs dark text on it (relative luminance).
    private static func isLight(_ hex: UInt32) -> Bool {
        let r = Double((hex >> 16) & 0xFF), g = Double((hex >> 8) & 0xFF), b = Double(hex & 0xFF)
        return (0.299 * r + 0.587 * g + 0.114 * b) / 255 > 0.6
    }
}

#Preview {
    VogueEditView().preferredColorScheme(.dark)
}
